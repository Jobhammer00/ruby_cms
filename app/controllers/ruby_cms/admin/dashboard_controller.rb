# frozen_string_literal: true

module RubyCms
  module Admin
    class DashboardController < BaseController
      # First main row: quick actions, recent errors, analytics (fixed keys). Remaining :main blocks render below (host/custom).
      PRIMARY_MAIN_ROW_KEYS = %i[quick_actions recent_errors analytics_overview].freeze

      def index
        assign_counts
        assign_recent_activity
        assign_analytics_overview_stats
        assign_dashboard_blocks
      end

      private

      def assign_analytics_overview_stats
        start_date = 7.days.ago.beginning_of_day
        end_date = Time.current.end_of_day
        @dashboard_analytics_stats = RubyCms::Analytics::Report.new(start_date:, end_date:).dashboard_stats
      rescue StandardError => e
        Rails.logger.warn("[RubyCMS] Dashboard analytics snapshot: #{e.class}: #{e.message}")
        @dashboard_analytics_stats = nil
      end

      def assign_dashboard_blocks
        visible = RubyCms.visible_dashboard_blocks(user: current_user_cms)
        @stats_blocks = visible
                        .select {|b| b[:section] == :stats }
                        .map {|b| prepare_dashboard_block(b) }
        main = visible
               .select {|b| b[:section] == :main }
               .map {|b| prepare_dashboard_block(b) }
        @primary_main_blocks = PRIMARY_MAIN_ROW_KEYS.filter_map {|k| main.find {|b| b[:key] == k } }
        @extra_main_blocks = main
                             .reject {|b| PRIMARY_MAIN_ROW_KEYS.include?(b[:key]) }
                             .sort_by {|b| [b[:order], b[:label].to_s] }
      end

      def prepare_dashboard_block(block)
        from_data =
          if block[:data].respond_to?(:call)
            block[:data].call(self)
          else
            {}
          end
        from_data = {} unless from_data.kind_of?(Hash)

        block.merge(locals: { dashboard_block: block }.merge(from_data))
      end

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
