# frozen_string_literal: true

module RubyCms
  module EngineDashboardRegistration
    def register_default_dashboard_blocks
      RubyCms.dashboard_register(
        key: :content_blocks_stats,
        label: "Content blocks",
        section: :stats,
        order: 1,
        partial: "ruby_cms/admin/dashboard/blocks/content_blocks_stats",
        permission: :manage_content_blocks
      )
      RubyCms.dashboard_register(
        key: :users_stats,
        label: "Users",
        section: :stats,
        order: 2,
        partial: "ruby_cms/admin/dashboard/blocks/users_stats",
        permission: :manage_permissions
      )
      RubyCms.dashboard_register(
        key: :permissions_stats,
        label: "Permissions",
        section: :stats,
        order: 3,
        partial: "ruby_cms/admin/dashboard/blocks/permissions_stats",
        permission: :manage_permissions
      )
      RubyCms.dashboard_register(
        key: :visitor_errors_stats,
        label: "Visitor errors",
        section: :stats,
        order: 4,
        partial: "ruby_cms/admin/dashboard/blocks/visitor_errors_stats",
        permission: :manage_visitor_errors
      )
      RubyCms.dashboard_register(
        key: :quick_actions,
        label: "Quick actions",
        section: :main,
        order: 1,
        span: :single,
        partial: "ruby_cms/admin/dashboard/blocks/quick_actions"
      )
      RubyCms.dashboard_register(
        key: :recent_errors,
        label: "Recent errors",
        section: :main,
        order: 2,
        span: :single,
        partial: "ruby_cms/admin/dashboard/blocks/recent_errors",
        permission: :manage_visitor_errors
      )
      RubyCms.dashboard_register(
        key: :analytics_overview,
        label: "Analytics",
        section: :main,
        order: 3,
        span: :single,
        partial: "ruby_cms/admin/dashboard/blocks/analytics_overview",
        permission: :manage_analytics
      )
    end
  end
end
