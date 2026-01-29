# frozen_string_literal: true

module RubyCms
  module Admin
    class ContentBlocksController < BaseController
      include RubyCms::AdminPagination
      include RubyCms::AdminTurboTable

      paginates per_page: 50, turbo_frame: "admin_table_content"

      before_action { require_permission!(:manage_content_blocks) }
      before_action :set_content_block, only: %i[show edit update destroy]

      def index
        collection = content_blocks_collection
        @content_blocks = html_index_blocks(collection)

        respond_to do |format|
          format.html { render_index_html }
          format.json { render json: json_index_blocks(collection) }
        end
      end

      def show
        respond_with_block(@content_block)
      end

      def new
        @content_block = ::ContentBlock.new(new_block_params)
      end

      def edit
        @blocks_by_locale = load_blocks_by_locale_for_edit
      end

      def create
        @content_block = ::ContentBlock.new(content_block_params)
        @content_block.record_update_by(current_user_cms)
        save_and_respond(@content_block, :new)
      end

      def update
        unified_locale_params? ? update_all_locales : update_single_block
      end

      def destroy
        @content_block.destroy
        redirect_with_notice("deleted")
      end

      # Bulk actions
      %i[bulk_delete bulk_publish bulk_unpublish].each do |action|
        define_method(action) { bulk_action(action) }
      end

      private

      def render_index_html
        if turbo_frame_request?
          render :index, layout: false
        else
          render :index
        end
      end

      def html_index_blocks(collection)
        grouped_or_paginated(collection) || []
      end

      def grouped_or_paginated(collection)
        if params[:locale].blank? && params[:q].blank?
          grouped_by_key_collection(collection)
        else
          paginate_collection(collection)
        end
      end

      def json_index_blocks(collection)
        { content_blocks: serialize_content_blocks(collection.limit(100)) }
      end

      def bulk_action(action)
        ids = Array(params[:item_ids]).filter_map(&:to_i).compact
        count = bulk_count_for(action, ids)
        turbo_redirect_with_count(action, count)
      end

      def bulk_count_for(action, ids)
        case action
        when :bulk_delete   then ::ContentBlock.where(id: ids).destroy_all.size
        when :bulk_publish  then bulk_set_published(ids, published: true)
        when :bulk_unpublish then bulk_set_published(ids, published: false)
        else 0
        end
      end

      def turbo_redirect_with_count(action, count)
        action_name = action.to_s.remove("bulk_")
        notice = "#{count} content block(s) #{action_name}."
        turbo_redirect_to ruby_cms_admin_content_blocks_path, notice:
      end

      def update_all_locales
        errors = build_locale_blocks_errors
        errors.any? ? handle_locale_update_errors(errors) : redirect_with_notice("updated")
      end

      def build_locale_blocks_errors
        locale_keys = content_block_permitted_params - %i[key locale]
        root_params = permitted_locale_params
        shared_content_type = root_params[:content_type].presence || @content_block.content_type
        shared_published = root_params[:published].to_s == "1"
        update_locale_blocks(root_params[:locales] || {}, locale_keys, shared_content_type,
                             shared_published)
      end

      def handle_locale_update_errors(errors)
        @content_block.errors.add(:base, errors.join("; "))
        @blocks_by_locale = load_blocks_by_locale_for_edit
        render :edit, status: :unprocessable_content
      end

      def update_single_block
        @content_block.record_update_by(current_user_cms)
        save_and_respond(@content_block, :edit)
      end

      def save_and_respond(block, failure_view)
        if block.save
          audit_if_json(block)
          respond_to_success(block)
        else
          respond_to_failure(block, failure_view)
        end
      end

      def audit_if_json(block)
        audit_visual_editor_edit(block.attributes) if request.format.json?
      end

      def respond_to_success(block)
        respond_to do |f|
          f.html do
            redirect_to ruby_cms_admin_content_block_path(block),
                        notice: t("ruby_cms.admin.content_blocks.updated")
          end
          f.json { head :no_content }
        end
      end

      def respond_to_failure(block, view)
        respond_to do |f|
          f.html { render view, status: :unprocessable_content }
          f.json do
            render json: { errors: block.errors.full_messages },
                   status: :unprocessable_content
          end
        end
      end

      def respond_with_block(block)
        respond_to do |f|
          f.html
          f.json { render json: content_block_editor_json(block) }
        end
      end

      def redirect_with_notice(action)
        redirect_to ruby_cms_admin_content_blocks_path,
                    notice: t("ruby_cms.admin.content_blocks.#{action}")
      end

      def set_content_block
        @content_block = ::ContentBlock.find(params[:id])
      end

      def load_blocks_by_locale_for_edit
        blocks = ::ContentBlock.where(key: @content_block.key).index_by(&:locale)
        I18n.available_locales.each_with_object({}) do |loc, hash|
          loc_s = loc.to_s
          hash[loc_s] = blocks[loc_s] || ::ContentBlock.new(
            key: @content_block.key, locale: loc_s,
            content_type: @content_block.content_type
          )
        end
      end

      def new_block_params
        return {} unless params[:content_block].kind_of?(ActionController::Parameters)

        params[:content_block].permit(:key, :locale).to_h
      end

      def content_block_params
        params.expect(content_block_param_root => [*content_block_permitted_params])
      end

      def content_block_param_root
        if params.key?(:content_block)
          :content_block
        else
          params.key?(:ruby_cms_content_block) ? :ruby_cms_content_block : :content_block
        end
      end

      def update_locale_blocks(locales_params, keys, shared_content_type, shared_published)
        locales_params.each.with_object([]) do |(locale_s, attrs), errors|
          next if attrs.blank?

          block = update_locale_block(locale_s, attrs, keys, shared_content_type, shared_published)
          next if block.save

          errors.concat(block.errors.full_messages.map {|m| "#{locale_s}: #{m}" })
        end
      end

      def update_locale_block(locale_s, attrs, keys, shared_content_type, shared_published)
        block = ::ContentBlock.find_or_initialize_by(key: @content_block.key, locale: locale_s)
        block.record_update_by(current_user_cms)
        attrs_permitted = attrs.permit(keys).to_h
        attrs_permitted.delete(:published)
        block.assign_attributes(
          attrs_permitted.merge(
            key: @content_block.key,
            locale: locale_s,
            content_type: shared_content_type,
            published: shared_published
          )
        )
        block
      end

      def permitted_locale_params
        params.expect(content_block: [:content_type, :published, { locales: {} }])
      end

      def unified_locale_params?
        params.dig(:content_block, :locales).present?
      end

      def bulk_set_published(ids, published:)
        updated_by_id = current_user_cms&.id
        # Expand to all locale variants of each selected block's key
        block_ids = ::ContentBlock.where(id: ids).flat_map do |b|
          ::ContentBlock.where(key: b.key).pluck(:id)
        end.uniq
        block_ids.reduce(0) do |sum, id|
          block = ::ContentBlock.find(id)
          block.updated_by_id = updated_by_id
          sum + (block.update(published:) ? 1 : 0)
        end
      end

      def content_block_editor_json(block)
        {
          id: block.id,
          key: block.key,
          title: block.title,
          content: block.content.to_s,
          content_type: block.content_type,
          published: block.published?,
          rich_content_html: block.respond_to?(:rich_content) ? block.rich_content.to_s : ""
        }
      end

      def content_blocks_collection
        apply_search_filter(apply_locale_filter(::ContentBlock.alphabetically.preloaded))
      end

      def apply_locale_filter(collection)
        return collection.for_locale(params[:locale]) if params[:locale].present?
        return collection if params[:search].present?

        collection.for_current_locale
      end

      def apply_search_filter(collection)
        search_term = params[:q] || params[:search]
        search_term.present? ? collection.search_by_term(search_term) : collection
      end

      def grouped_by_key_collection(collection)
        RubyCms::ContentBlocksGrouping.group_by_key(collection)
      end

      def serialize_content_blocks(scope)
        scope.map do |block|
          {
            id: block.id,
            key: block.key,
            locale: block.locale,
            title: block.title,
            content: block.content.to_s,
            content_type: block.content_type,
            published: block.published?,
            rich_content: block.respond_to?(:rich_content) ? block.rich_content.to_s : "",
            updated_at: block.updated_at.strftime("%B %d, %Y at %I:%M %p")
          }
        end
      end

      def audit_visual_editor_edit(changes)
        Rails.application.config.ruby_cms.audit_editor_edit&.call(
          @content_block.id,
          current_user_cms&.id, changes.to_h
        )
      end

      def content_block_permitted_params
        %i[key locale title content content_type published].tap do |arr|
          arr << :rich_content if action_text_available?
          arr << :image if active_storage_available?
        end
      end

      def action_text_available?
        ::ContentBlock.respond_to?(:action_text_available?) && ::ContentBlock.action_text_available?
      end

      def active_storage_available?
        ::ContentBlock.respond_to?(:active_storage_available?) &&
          ::ContentBlock.active_storage_available?
      end
    end
  end
end
