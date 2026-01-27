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
        collection = RubyCms::ContentBlock.by_key.includes(:updated_by)

        # Filter by locale if provided
        if params[:locale].present?
          collection = collection.for_locale(params[:locale])
        elsif params[:search].present?
          # For visual editor search, don't filter by locale - search across all locales
          # This allows finding blocks regardless of current locale
        else
          # Default to current locale only when not searching
          collection = collection.for_current_locale
        end

        # Support search parameter for visual editor
        if params[:search].present?
          collection = collection.where("key LIKE ?", "%#{params[:search]}%")
        end

        respond_to do |format|
          format.html do
            @content_blocks = paginate_collection(collection)
            @content_blocks ||= RubyCms::ContentBlock.none
          end
          format.json do
            blocks = collection.limit(100).map do |block|
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
            render json: { content_blocks: blocks }
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
        @content_block = RubyCms::ContentBlock.new
      end

      def edit; end

      def create
        @content_block = RubyCms::ContentBlock.new(content_block_params)
        @content_block.updated_by = current_user_cms

        if @content_block.save
          redirect_to ruby_cms_admin_content_block_path(@content_block),
                      notice: "Content block created."
        else
          render :new, status: :unprocessable_content
        end
      end

      def update
        @content_block.updated_by = current_user_cms

        cp = content_block_params
        if @content_block.update(cp)
          if request.format.json?
            Rails.application.config.ruby_cms.audit_editor_edit&.call(@content_block.id, current_user_cms&.id,
                                                                      cp.to_h)
          end
          respond_to do |format|
            format.html do
              redirect_to ruby_cms_admin_content_block_path(@content_block),
                          notice: "Content block updated."
            end
            format.json { head :no_content }
          end
        else
          respond_to do |format|
            format.html { render :edit, status: :unprocessable_content }
            format.json do
              render json: { errors: @content_block.errors.full_messages },
                     status: :unprocessable_content
            end
          end
        end
      end

      def destroy
        @content_block.destroy
        redirect_to ruby_cms_admin_content_blocks_path, notice: "Content block deleted."
      end

      def bulk_delete
        ids = Array(params[:item_ids]).map(&:to_i).compact
        content_blocks = RubyCms::ContentBlock.where(id: ids)
        count = content_blocks.count
        content_blocks.destroy_all
        turbo_redirect_to ruby_cms_admin_content_blocks_path,
                          notice: "#{count} content block(s) deleted."
      end

      def bulk_publish
        ids = Array(params[:item_ids]).map(&:to_i).compact
        count = RubyCms::ContentBlock.where(id: ids).update_all(published: true,
                                                                updated_at: Time.current, updated_by_id: current_user_cms&.id)
        redirect_to ruby_cms_admin_content_blocks_path,
                    notice: "#{count} content block(s) published."
      end

      def bulk_unpublish
        ids = Array(params[:item_ids]).map(&:to_i).compact
        count = RubyCms::ContentBlock.where(id: ids).update_all(published: false,
                                                                updated_at: Time.current, updated_by_id: current_user_cms&.id)
        redirect_to ruby_cms_admin_content_blocks_path,
                    notice: "#{count} content block(s) unpublished."
      end

      private

      def set_content_block
        @content_block = RubyCms::ContentBlock.find(params[:id])
      end

      def content_block_params
        root =
          if params.key?(:content_block)
            :content_block
          elsif params.key?(:ruby_cms_content_block)
            :ruby_cms_content_block
          else
            :content_block
          end

        permitted = %i[key locale title content content_type published]
        if RubyCms::ContentBlock.respond_to?(:action_text_available?) && RubyCms::ContentBlock.action_text_available?
          permitted << :rich_content
        end
        if RubyCms::ContentBlock.respond_to?(:active_storage_available?) && RubyCms::ContentBlock.active_storage_available?
          permitted << :image
        end

        params.require(root).permit(*permitted)
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
    end
  end
end
