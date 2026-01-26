# frozen_string_literal: true

module RubyCms
  module Admin
    class ContentBlocksController < BaseController
      INDEX_LIMIT = 50

      before_action { require_permission!(:manage_content_blocks) }
      before_action :set_content_block, only: %i[show edit update destroy]

      def index
        @content_blocks = RubyCms::ContentBlock.by_key.includes(:updated_by).limit(INDEX_LIMIT)
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

      def create
        @content_block = RubyCms::ContentBlock.new(content_block_params)
        @content_block.updated_by = current_user_cms

        if @content_block.save
          redirect_to ruby_cms_admin_content_block_path(@content_block), notice: "Content block created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

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
              redirect_to ruby_cms_admin_content_block_path(@content_block), notice: "Content block updated."
            end
            format.json { head :no_content }
          end
        else
          respond_to do |format|
            format.html { render :edit, status: :unprocessable_entity }
            format.json { render json: { errors: @content_block.errors.full_messages }, status: :unprocessable_entity }
          end
        end
      end

      def destroy
        @content_block.destroy
        redirect_to ruby_cms_admin_content_blocks_path, notice: "Content block deleted."
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

        permitted = %i[key title content content_type published]
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
