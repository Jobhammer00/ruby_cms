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

        respond_to do |format|
          format.html do
            @content_blocks = paginate_collection(collection)
            @content_blocks ||= ::ContentBlock.none
          end
          format.json do
            render json: { content_blocks: serialize_content_blocks(collection.limit(100)) }
          end
        end
      end

      def show
        respond_to do |format|
          format.html
          format.json { render json: content_block_editor_json(@content_block) }
        end
      end

      def new
        @content_block = ::ContentBlock.new
      end

      def edit; end

      def create
        @content_block = ::ContentBlock.new(content_block_params)
        @content_block.updated_by = current_user_cms

        if @content_block.save
          redirect_to ruby_cms_admin_content_block_path(@content_block),
                      notice: t("ruby_cms.admin.content_blocks.created")
        else
          render :new, status: :unprocessable_content
        end
      end

      def update
        @content_block.updated_by = current_user_cms

        cp = content_block_params
        if @content_block.update(cp)
          audit_visual_editor_edit(cp) if request.format.json?
          respond_after_update_success
        else
          respond_after_update_failure
        end
      end

      def destroy
        @content_block.destroy
        redirect_to ruby_cms_admin_content_blocks_path,
                    notice: t("ruby_cms.admin.content_blocks.deleted")
      end

      def bulk_delete
        ids = Array(params[:item_ids]).filter_map(&:to_i).compact
        content_blocks = ::ContentBlock.where(id: ids)
        count = content_blocks.count
        content_blocks.destroy_all
        turbo_redirect_to ruby_cms_admin_content_blocks_path,
                          notice: "#{count} content block(s) deleted."
      end

      def bulk_publish
        ids = Array(params[:item_ids]).filter_map(&:to_i).compact
        count = bulk_set_published(ids, published: true)
        redirect_to ruby_cms_admin_content_blocks_path,
                    notice: "#{count} content block(s) published."
      end

      def bulk_unpublish
        ids = Array(params[:item_ids]).filter_map(&:to_i).compact
        count = bulk_set_published(ids, published: false)
        redirect_to ruby_cms_admin_content_blocks_path,
                    notice: "#{count} content block(s) unpublished."
      end

      private

      def set_content_block
        @content_block = ::ContentBlock.find(params[:id])
      end

      def content_block_params
        params.expect(content_block_param_root => [*content_block_permitted_params])
      end

      def content_block_editor_json(block)
        {
          id: block.id,
          key: block.key,
          title: block.title,
          content: block.content.to_s,
          content_type: block.content_type,
          published: block.published?,
          rich_content_html: (block.respond_to?(:rich_content) ? block.rich_content.to_s : "")
        }
      end

      def content_blocks_collection
        collection = ::ContentBlock.by_key.includes(:updated_by)
        collection = apply_locale_filter(collection)
        apply_search_filter(collection)
      end

      def apply_locale_filter(collection)
        return collection.for_locale(params[:locale]) if params[:locale].present?
        return collection if params[:search].present?

        collection.for_current_locale
      end

      def apply_search_filter(collection)
        search_param = params[:q] || params[:search]
        return collection if search_param.blank?

        search_term = "%#{search_param.downcase}%"
        collection.where("LOWER(key) LIKE ? OR LOWER(title) LIKE ?", search_term, search_term)
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
            rich_content: (block.respond_to?(:rich_content) ? block.rich_content.to_s : ""),
            updated_at: block.updated_at.strftime("%B %d, %Y at %I:%M %p")
          }
        end
      end

      def audit_visual_editor_edit(changes)
        Rails.application.config.ruby_cms.audit_editor_edit&.call(
          @content_block.id,
          current_user_cms&.id,
          changes.to_h
        )
      end

      def respond_after_update_success
        respond_to do |format|
          format.html do
            redirect_to ruby_cms_admin_content_block_path(@content_block),
                        notice: t("ruby_cms.admin.content_blocks.updated")
          end
          format.json { head :no_content }
        end
      end

      def respond_after_update_failure
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_content }
          format.json do
            render json: { errors: @content_block.errors.full_messages },
                   status: :unprocessable_content
          end
        end
      end

      def bulk_set_published(ids, published:)
        updated_by_id = current_user_cms&.id
        count = 0

        ::ContentBlock.where(id: ids).find_each do |block|
          block.updated_by_id = updated_by_id
          count += 1 if block.update(published:)
        end

        count
      end

      def content_block_param_root
        return :content_block if params.key?(:content_block)
        return :ruby_cms_content_block if params.key?(:ruby_cms_content_block)

        :content_block
      end

      def content_block_permitted_params
        permitted = %i[key locale title content content_type published]
        permitted << :rich_content if action_text_available?
        permitted << :image if active_storage_available?
        permitted
      end

      def action_text_available?
        ::ContentBlock.respond_to?(:action_text_available?) &&
          ::ContentBlock.action_text_available?
      end

      def active_storage_available?
        ::ContentBlock.respond_to?(:active_storage_available?) &&
          ::ContentBlock.active_storage_available?
      end
    end
  end
end
