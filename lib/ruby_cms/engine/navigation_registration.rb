# frozen_string_literal: true

module RubyCms
  module EngineNavigationRegistration
    def register_main_nav_items
      RubyCms.register_page(
        key: :dashboard,
        label: "Dashboard",
        path: lambda(&:ruby_cms_admin_root_path),
        icon: :home,
        permission: :manage_admin,
        order: 1
      )
      RubyCms.register_page(
        key: :visual_editor,
        label: "Visual editor",
        path: lambda(&:ruby_cms_admin_visual_editor_path),
        icon: :pencil_square,
        permission: :manage_content_blocks,
        order: 2
      )
      RubyCms.register_page(
        key: :content_blocks,
        label: "Content blocks",
        path: lambda(&:ruby_cms_admin_content_blocks_path),
        icon: :document_duplicate,
        permission: :manage_content_blocks,
        order: 3
      )
    end

    def register_settings_nav_items
      RubyCms.register_page(
        key: :analytics,
        label: "Analytics",
        path: lambda(&:ruby_cms_admin_analytics_path),
        icon: :chart_bar,
        section: :settings,
        permission: :manage_analytics,
        order: 1
      )
      RubyCms.register_page(
        key: :visitor_errors,
        label: "Visitor errors",
        path: lambda(&:ruby_cms_admin_visitor_errors_path),
        icon: :exclamation_triangle,
        section: :settings,
        permission: :manage_visitor_errors,
        order: 2
      )
      RubyCms.register_page(
        key: :permissions,
        label: "Permissions",
        path: lambda(&:ruby_cms_admin_permissions_path),
        icon: :shield_check,
        section: :settings,
        permission: :manage_permissions,
        order: 10
      )
      RubyCms.register_page(
        key: :users,
        label: "Users",
        path: lambda(&:ruby_cms_admin_users_path),
        icon: :user_group,
        section: :settings,
        permission: :manage_permissions,
        order: 20
      )
      RubyCms.register_page(
        key: :commands,
        label: "Commands",
        path: lambda(&:ruby_cms_admin_settings_commands_path),
        icon: :wrench,
        section: :settings,
        permission: :manage_admin,
        order: 30
      )
      RubyCms.nav_group(
        key: :settings,
        label: "Settings",
        path: lambda(&:ruby_cms_admin_settings_path),
        icon: :cog_6_tooth,
        section: RubyCms::NAV_SECTION_BOTTOM,
        children: %i[permissions users commands],
        default_open: false,
        order: 3
      )
    end
  end
end
