# frozen_string_literal: true

module RubyCms
  module Admin
    class ContentBlockVersionsController < BaseController
      before_action { require_permission!(:manage_content_blocks) }
      before_action :set_content_block
      before_action :set_version, only: %i[show rollback]

      def index
        @versions = @content_block.versions.reverse_chronologically.preloaded

        respond_to do |format|
          format.html
          format.json { render json: versions_json }
        end
      end

      def show
        @previous_version = @version.previous
      end

      def rollback
        @content_block.rollback_to_version!(@version, user: current_user_cms)
        redirect_to ruby_cms_admin_content_block_versions_path(@content_block),
                    notice: "Teruggedraaid naar versie #{@version.version_number}"
      end

      private

      def set_content_block
        @content_block = ContentBlock.find(params[:content_block_id])
      end

      def set_version
        @version = @content_block.versions.find(params[:id])
      end

      def versions_json
        @versions.map do |v|
          {
            id: v.id,
            version_number: v.version_number,
            event: v.event,
            user: display_user(v.user),
            created_at: v.created_at.strftime("%B %d, %Y at %I:%M %p"),
            metadata: v.metadata
          }
        end
      end

      def display_user(user)
        return "System" if user.blank?

        %i[email_address email username name].each do |attr|
          return user.public_send(attr) if user.respond_to?(attr) && user.public_send(attr).present?
        end
        user.respond_to?(:id) ? "User ##{user.id}" : "System"
      end
    end
  end
end
