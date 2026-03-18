# frozen_string_literal: true

module RubyCms
  module Admin
    class DashboardController < BaseController
      def index
        assign_counts
        assign_recent_activity
      end

      private

      def assign_counts
        @content_blocks_count = ::ContentBlock.count
        @content_blocks_published_count = ::ContentBlock.published.count
        @permissions_count = RubyCms::Permission.count
        @user_permissions_count = RubyCms::UserPermission.count
        @users_count = safe_user_count
        @visitor_errors_count = RubyCms::VisitorError.count
        @unresolved_errors_count = RubyCms::VisitorError.unresolved.count
      end

      def assign_recent_activity
        @recent_errors = RubyCms::VisitorError.order(created_at: :desc).limit(recent_errors_limit)
        @recent_content_blocks =
          ::ContentBlock.order(updated_at: :desc).limit(recent_content_blocks_limit)
      end

      def safe_user_count
        user_class.count
      rescue StandardError
        0
      end

      def user_class
        Object.const_get(
          Rails.application.config.ruby_cms.user_class_name.presence || "User"
        )
      end

      def recent_errors_limit
        RubyCms::Settings.get(:dashboard_recent_errors_limit, default: 5).to_i
      end

      def recent_content_blocks_limit
        RubyCms::Settings.get(:dashboard_recent_content_blocks_limit, default: 5).to_i
      end
    end
  end
end
