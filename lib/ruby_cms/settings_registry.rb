# frozen_string_literal: true

module RubyCms
  module SettingsRegistry
    Entry = Struct.new(
      :key,
      :type,
      :default,
      :category,
      :description,
      keyword_init: true
    )

    mattr_accessor :entries, default: {}

    class << self
      def register(key:, type:, default:, category: "general", description: nil)
        k = key.to_s
        entries[k] = Entry.new(
          key: k,
          type: normalize_type(type),
          default: default,
          category: category.to_s,
          description: description.to_s
        )
      end

      def fetch(key)
        entries[key.to_s]
      end

      def each(&block)
        entries.each_value(&block)
      end

      def defaults_hash
        seed_defaults! if entries.empty?

        entries.values.each_with_object({}) do |entry, hash|
          hash[entry.key.to_sym] = {
            value: entry.default,
            type: value_type_for(entry.type),
            description: entry.description,
            category: entry.category
          }
        end
      end

      def seed_defaults!
        return unless entries.empty?

        # Pagination
        register(
          key: :visitor_errors_per_page,
          type: :integer,
          default: 25,
          category: :pagination,
          description: "Number of visitor errors to show per page"
        )
        register(
          key: :content_blocks_per_page,
          type: :integer,
          default: 50,
          category: :pagination,
          description: "Number of content blocks to show per page"
        )
        register(
          key: :users_per_page,
          type: :integer,
          default: 50,
          category: :pagination,
          description: "Number of users to show per page"
        )
        register(
          key: :permissions_per_page,
          type: :integer,
          default: 50,
          category: :pagination,
          description: "Number of permissions to show per page"
        )
        register(
          key: :pagination_min_per_page,
          type: :integer,
          default: 5,
          category: :pagination,
          description: "Minimum allowed per-page size"
        )
        register(
          key: :pagination_max_per_page,
          type: :integer,
          default: 200,
          category: :pagination,
          description: "Maximum allowed per-page size"
        )

        # Analytics
        register(
          key: :analytics_high_volume_threshold,
          type: :integer,
          default: 1000,
          category: :analytics,
          description: "Threshold of visits per IP in selected period to flag high volume traffic"
        )
        register(
          key: :analytics_rapid_request_threshold,
          type: :integer,
          default: 50,
          category: :analytics,
          description: "Threshold of visits from an IP per minute to flag rapid requests"
        )
        register(
          key: :analytics_default_period,
          type: :string,
          default: "week",
          category: :analytics,
          description: "Default analytics period (day/week/month/year)"
        )
        register(
          key: :analytics_max_date_range_days,
          type: :integer,
          default: 365,
          category: :analytics,
          description: "Maximum date range for analytics filters"
        )
        register(
          key: :analytics_max_popular_pages,
          type: :integer,
          default: 10,
          category: :analytics,
          description: "Maximum number of popular pages to show"
        )
        register(
          key: :analytics_max_top_visitors,
          type: :integer,
          default: 10,
          category: :analytics,
          description: "Maximum number of top visitors to show"
        )
        register(
          key: :analytics_cache_duration_seconds,
          type: :integer,
          default: 600,
          category: :analytics,
          description: "Analytics cache duration in seconds"
        )
        register(
          key: :analytics_recent_page_views_limit,
          type: :integer,
          default: 25,
          category: :analytics,
          description: "Recent page views shown on analytics dashboard"
        )
        register(
          key: :analytics_page_details_limit,
          type: :integer,
          default: 100,
          category: :analytics,
          description: "Events shown on page details screen"
        )
        register(
          key: :analytics_visitor_details_limit,
          type: :integer,
          default: 100,
          category: :analytics,
          description: "Events shown on visitor details screen"
        )

        # Dashboard
        register(
          key: :dashboard_recent_errors_limit,
          type: :integer,
          default: 5,
          category: :dashboard,
          description: "Recent visitor errors shown on dashboard"
        )
        register(
          key: :dashboard_recent_content_blocks_limit,
          type: :integer,
          default: 5,
          category: :dashboard,
          description: "Recent content blocks shown on dashboard"
        )

        # Navigation visibility
        register(
          key: :nav_show_dashboard,
          type: :boolean,
          default: true,
          category: :navigation,
          description: "Show Dashboard in navigation"
        )
        register(
          key: :nav_show_visual_editor,
          type: :boolean,
          default: true,
          category: :navigation,
          description: "Show Visual Editor in navigation"
        )
        register(
          key: :nav_show_content_blocks,
          type: :boolean,
          default: true,
          category: :navigation,
          description: "Show Content Blocks in navigation"
        )
        register(
          key: :nav_show_settings,
          type: :boolean,
          default: true,
          category: :navigation,
          description: "Show Settings in navigation"
        )
        register(
          key: :nav_show_visitor_errors,
          type: :boolean,
          default: true,
          category: :navigation,
          description: "Show Visitor Errors in navigation"
        )
        register(
          key: :nav_show_permissions,
          type: :boolean,
          default: true,
          category: :navigation,
          description: "Show Permissions in navigation"
        )
        register(
          key: :nav_show_users,
          type: :boolean,
          default: true,
          category: :navigation,
          description: "Show Users in navigation"
        )
        register(
          key: :nav_show_analytics,
          type: :boolean,
          default: true,
          category: :navigation,
          description: "Show Analytics in navigation"
        )
        register(
          key: :nav_order,
          type: :json,
          default: [],
          category: :navigation,
          description: "Order of nav items (set via Settings → Navigation drag-and-drop)"
        )

        # Content/image constraints
        register(
          key: :reserved_key_prefixes,
          type: :json,
          default: ["admin_"],
          category: :content,
          description: "Reserved prefixes blocked for content block keys"
        )
        register(
          key: :image_content_types,
          type: :json,
          default: ["image/png", "image/jpeg", "image/gif", "image/webp"],
          category: :content,
          description: "Allowed MIME types for content block images"
        )
        register(
          key: :image_max_size,
          type: :integer,
          default: 5 * 1024 * 1024,
          category: :content,
          description: "Max image attachment size in bytes"
        )
      end

      private

      def normalize_type(type)
        t = type.to_sym
        return t if %i[string integer boolean json].include?(t)

        :string
      end

      def value_type_for(type)
        normalize_type(type).to_s
      end
    end
  end
end
