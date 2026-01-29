# frozen_string_literal: true

module RubyCms
  module Admin
    class DashboardController < BaseController
      def index
        @content_blocks_count = ::ContentBlock.count
        @content_blocks_published_count = ::ContentBlock.published.count
        @permissions_count = RubyCms::Permission.count
        @user_permissions_count = RubyCms::UserPermission.count

        @users_count = begin
          user_class.count
        rescue StandardError
          0
        end
      end

      private

      def user_class
        Object.const_get(
          Rails.application.config.ruby_cms.user_class_name.presence || "User"
        )
      end
    end
  end
end
