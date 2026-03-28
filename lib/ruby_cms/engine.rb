# frozen_string_literal: true

require_relative "settings_registry"
require_relative "settings"
require_relative "dashboard_blocks"

module RubyCms
  class Engine < ::Rails::Engine
    # Do not isolate namespace so we can use /admin and explicit table names.
    # Engine models use unprefixed table names: content_blocks, preferences, permissions, user_permissions, visitor_errors.

    config.ruby_cms = ActiveSupport::OrderedOptions.new

    # Base controller for all /admin controllers. Must provide current_user and
    # run require_authentication (or equivalent). Default: ApplicationController.
    config.ruby_cms.admin_base_controller = "ApplicationController"
    # Layout used for /admin pages. Default: "admin/admin" (app's layouts/admin/admin.html.erb).
    config.ruby_cms.admin_layout = "admin/admin"
    config.ruby_cms.user_class_name = "User"

    # When true, allow user.admin? as bypass when no Permission records exist (bootstrap).
    config.ruby_cms.bootstrap_admin_with_role = true

    # Path to redirect to when unauthenticated or not permitted (e.g. "/" or "/session/new").
    # main_app.root_path is not used by default because the host may not define a root route.
    config.ruby_cms.unauthorized_redirect_path = "/"

    # Callable to resolve "current user" from the request. Receives controller, returns user or nil.
    # Default: ->(c) { c.respond_to?(:current_user) ? c.current_user : nil }
    config.ruby_cms.current_user_resolver = lambda {|controller|
      controller.respond_to?(:current_user) ? controller.current_user : nil
    }

    # Visual editor: allowlist of page_key => template path (e.g. "home" => "pages/home").
    # Can be extended by Page model: Page.preview_templates_hash merges config with Page records.
    config.ruby_cms.preview_templates = {}
    # Proc to inject preview data: ->(page_key, view_context) { { @products => [] } }
    config.ruby_cms.preview_data = ->(_page_key, _view) { {} }
    # Optional: audit edits from the visual editor. ->(content_block_id, user_id, changes) { }
    config.ruby_cms.audit_editor_edit = nil

    # Content blocks: reserved key prefixes (e.g. "admin_") cannot be used.
    config.ruby_cms.reserved_key_prefixes = %w[admin_]
    # Content blocks: default translation namespace
    # (e.g., "content_blocks" or "cms")
    # When set, content_block helper will try translations
    # at namespace.key before root-level key
    # Example: If namespace is "content_blocks",
    # it tries "content_blocks.home_hero_title" then "home_hero_title"
    config.ruby_cms.content_blocks_translation_namespace = nil
    # Image attachment: allowed content types and max size.
    config.ruby_cms.image_content_types = %w[image/png image/jpeg image/gif image/webp]
    # Keep this numeric so engine boot does not depend on core-ext load order.
    config.ruby_cms.image_max_size = 5 * 1024 * 1024

    # Ensure Ahoy is loaded before host's config/initializers/ahoy.rb runs
    initializer "ruby_cms.require_ahoy", before: :load_config_initializers do
      require "ahoy_matey"
    end

    initializer "ruby_cms.i18n" do |app|
      app.config.i18n.load_path += Dir[config.root.join("config", "locales", "**", "*.yml")]
    end

    initializer "ruby_cms.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper RubyCms::ApplicationHelper
        helper RubyCms::ContentBlocksHelper
        helper RubyCms::SettingsHelper
        helper RubyCms::BulkActionTableHelper
        helper RubyCms::Admin::BulkActionTableHelper
        helper RubyCms::Admin::AdminPageHelper
        helper RubyCms::Admin::DashboardHelper
      end
    end

    initializer "ruby_cms.assets", before: :load_config_initializers do |app|
      # Add JavaScript controllers to asset pipeline (before importmap resolves)
      app.config.assets.paths.unshift(config.root.join("app/javascript")) if app.config.respond_to?(:assets)
      # Add stylesheets to asset pipeline
      app.config.assets.paths << config.root.join("app/assets/stylesheets") if app.config.respond_to?(:assets)
      # Images (sidebar logo, etc.) — required for Propshaft/Sprockets `image_tag "ruby_cms/logo.png"`
      app.config.assets.paths << config.root.join("app/assets/images") if app.config.respond_to?(:assets)
    end

    initializer "ruby_cms.importmap", before: "importmap" do |app|
      # For importmap: ensure engine's importmap is loaded
      if app.config.respond_to?(:importmap)
        app.config.importmap.paths << config.root.join("config/importmap.rb")
        app.config.importmap.cache_sweepers << config.root.join("app/javascript")
      end
    end

    initializer "ruby_cms.nav" do
      Rails.application.config.to_prepare do
        RubyCms::Engine.register_main_nav_items
        RubyCms::Engine.register_settings_nav_items
      end
    end

    initializer "ruby_cms.dashboard_blocks" do
      RubyCms::Engine.register_default_dashboard_blocks
    end

    initializer "ruby_cms.versionable" do
      Rails.application.config.to_prepare do
        ContentBlock.include(ContentBlock::Versionable) unless ContentBlock.ancestors.include?(ContentBlock::Versionable)
      end
    end

    initializer "ruby_cms.settings_import", after: :load_config_initializers do
      RubyCms::Settings.import_initializer_values!
    end

    # After host initializers (e.g. register_permission_keys), ensure Permission rows exist
    # so can?(:manage_backups) and other keys do not fail on Permission.exists? checks.
    initializer "ruby_cms.ensure_permission_rows", after: :load_config_initializers do
      RubyCms::Permission.ensure_defaults!
    rescue StandardError => e
      Rails.logger.warn("[RubyCMS] Permission.ensure_defaults! skipped: #{e.message}")
    end

    def self.register_default_dashboard_blocks
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

    def self.register_main_nav_items
      RubyCms.nav_register(
        key: :dashboard,
        label: "Dashboard",
        path: lambda(&:ruby_cms_admin_root_path),
        icon: dashboard_icon_path,
        section: RubyCms::NAV_SECTION_MAIN,
        permission: :manage_admin,
        order: 1
      )
      RubyCms.nav_register(
        key: :visual_editor,
        label: "Visual editor",
        path: lambda(&:ruby_cms_admin_visual_editor_path),
        icon: visual_editor_icon_path,
        section: RubyCms::NAV_SECTION_MAIN,
        permission: :manage_content_blocks,
        order: 2
      )
      RubyCms.nav_register(
        key: :content_blocks,
        label: "Content blocks",
        path: lambda(&:ruby_cms_admin_content_blocks_path),
        icon: content_blocks_icon_path,
        section: RubyCms::NAV_SECTION_MAIN,
        permission: :manage_content_blocks,
        order: 3
      )
    end

    def self.dashboard_icon_path
      # Heroicons HomeIcon (outline)
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
        'd="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3' \
        'm-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>'
    end

    def self.content_blocks_icon_path
      # Heroicons DocumentDuplicateIcon (outline)
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
        'd="M8 7v8a2 2 0 002 2h6M8 7V5a2 2 0 012-2h4.586a1 1 0 01.707.293l4.414 4.414' \
        'a1 1 0 01.293.707V15a2 2 0 01-2 2h-2M8 7H6a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 ' \
        '0 002-2v-2"></path>'
    end

    def self.visual_editor_icon_path
      # Heroicons PencilSquareIcon (outline)
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
        'd="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 ' \
        '0 012.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>'
    end

    def self.register_settings_nav_items
      RubyCms.nav_register(
        key: :analytics,
        label: "Analytics",
        path: lambda(&:ruby_cms_admin_analytics_path),
        section: RubyCms::NAV_SECTION_BOTTOM,
        icon: analytics_icon_path,
        permission: :manage_analytics,
        order: 1
      )
      RubyCms.nav_register(
        key: :permissions,
        label: "Permissions",
        path: lambda(&:ruby_cms_admin_permissions_path),
        section: RubyCms::NAV_SECTION_BOTTOM,
        icon: permissions_icon_path,
        permission: :manage_permissions,
        order: 2
      )
      RubyCms.nav_register(
        key: :visitor_errors,
        label: "Visitor errors",
        path: lambda(&:ruby_cms_admin_visitor_errors_path),
        section: RubyCms::NAV_SECTION_BOTTOM,
        icon: visitor_errors_icon_path,
        permission: :manage_visitor_errors,
        order: 3
      )
      RubyCms.nav_register(
        key: :users,
        label: "Users",
        path: lambda(&:ruby_cms_admin_users_path),
        section: RubyCms::NAV_SECTION_BOTTOM,
        icon: users_icon_path,
        permission: :manage_permissions,
        order: 4
      )
      RubyCms.nav_register(
        key: :settings,
        label: "Settings",
        path: lambda(&:ruby_cms_admin_settings_path),
        section: RubyCms::NAV_SECTION_BOTTOM,
        icon: settings_icon_path,
        permission: :manage_admin,
        order: 5
      )
    end

    def self.settings_icon_path
      # Heroicons Cog6ToothIcon (outline)
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
        'd="M9.594 3.94c.09-.542.56-.94 1.11-.94h2.593c.55 0 1.02.398 1.11.94l.213 ' \
        '1.281c.063.374.313.686.645.87.074.04.147.083.22.127.324.196.72.257 1.075.124l1.217-.456a1.125 ' \
        '1.125 0 011.37.49l1.296 2.247a1.125 1.125 0 01-.26 1.431l-1.003.827c-.293.24-.438.613-.431.992a6.759 ' \
        '6.759 0 010 .255c-.007.378.138.75.43.99l1.005.828c.424.35.534.954.26 1.43l-1.298 2.247a1.125 1.125 ' \
        '0 01-1.369.491l-1.217-.456c-.355-.133-.75-.072-1.076.124a6.57 6.57 0 01-.22.128c-.331.183-.581.495-.644.869l-.213 ' \
        '1.28c-.09.543-.56.941-1.11.941h-2.594c-.55 0-1.02-.398-1.11-.94l-.213-1.281c-.062-.374-.312-.686-.644-.87a6.52 ' \
        '6.52 0 01-.22-.127c-.325-.196-.72-.257-1.076-.124l-1.217.456a1.125 1.125 0 01-1.369-.49l-1.297-2.247a1.125 ' \
        '1.125 0 01.26-1.431l1.004-.827c.292-.24.437-.613.43-.992a6.932 6.932 0 010-.255c.007-.378-.138-.75-.43-.99l-1.004-.828a1.125 ' \
        '1.125 0 01-.26-1.43l1.297-2.247a1.125 1.125 0 011.37-.491l1.216.456c.356.133.751.072 1.076-.124.072-.044.146-.087.22-.128.332-.183.582-.495.644-.869l.214-1.281z"></path>' \
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>'
    end

    def self.visitor_errors_icon_path
      # Heroicons ExclamationTriangleIcon (outline)
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
        'd="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 ' \
        '4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"></path>'
    end

    def self.permissions_icon_path
      # Heroicons ShieldCheckIcon (outline)
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
        'd="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01' \
        '-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 ' \
        '9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path>'
    end

    def self.users_icon_path
      # Heroicons UserGroupIcon (outline)
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
        'd="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 ' \
        '00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>'
    end

    def self.analytics_icon_path
      '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
        'd="M3 3v18h18"></path>' \
        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
        'd="M7 13l3-3 3 2 4-5"></path>'
    end

    def self.compile_admin_css(dest_path)
      gem_root = begin
        root
      rescue StandardError
        Pathname.new(File.expand_path("../..", __dir__))
      end
      RubyCms::CssCompiler.compile(gem_root, dest_path)
    end

    config.paths.add "db/migrate", with: "db/migrate"

    rake_tasks do # rubocop:disable Metrics/BlockLength
      namespace :ruby_cms do # rubocop:disable Metrics/BlockLength
        desc "Create default permissions/settings and optionally grant manage_admin to admin users"
        task seed_permissions: :environment do
          RubyCms::Permission.ensure_defaults!
          RubyCms::Settings.ensure_defaults!
          RubyCms::Settings.import_initializer_values!
          RubyCms::Engine.grant_admin_permissions_to_admin_users
        end
        desc "Import RubyCMS initializer values into DB settings once"
        task import_initializer_settings: :environment do
          result = RubyCms::Settings.import_initializer_values!
          if result[:skipped]
            puts "Initializer import skipped: #{result[:reason]}" # rubocop:disable Rails/Output
          else
            puts "Imported #{result[:imported_count]} initializer setting(s)." # rubocop:disable Rails/Output
          end
        end

        desc "Interactively create or select the first admin user " \
             "and grant full permissions (manage_admin, manage_permissions, " \
             "manage_content_blocks, etc.)"
        task setup_admin: :environment do
          require "ruby_cms/cli"
          RubyCms::RunSetupAdmin.call(shell: Thor::Shell::Basic.new)
        end

        desc "Grant manage_admin to a user by email. " \
             "Usage: rails ruby_cms:grant_manage_admin email=user@example.com"
        task :grant_manage_admin, [:email] => :environment do |_t, args|
          email = RubyCms::Engine.extract_email_from_args(args)
          RubyCms::Engine.validate_email_present(email)

          RubyCms::Permission.ensure_defaults!
          user = RubyCms::Engine.find_user_by_email(email)
          RubyCms::Engine.validate_user_found(user, email)

          RubyCms::Engine.grant_manage_admin_permission(user, email)
        end

        namespace :content_blocks do # rubocop:disable Metrics/BlockLength
          desc "Export content blocks from database to YAML locale files"
          task :export, %i[namespace locales_dir] => :environment do |_t, args|
            require "ruby_cms/content_blocks_sync"

            namespace = args[:namespace].presence
            locales_dir = RubyCms::Engine.parse_locales_dir(args[:locales_dir])
            flatten = ENV["flatten"] == "true"

            sync = RubyCms::ContentBlocksSync.new(namespace:, locales_dir:)
            summary = sync.export_to_yaml(only_published: true, flatten_keys: flatten)

            RubyCms::Engine.display_export_summary(summary)
          end

          desc "Import content blocks from YAML locale files to database"
          task :import, %i[locale namespace locales_dir] => :environment do |_t, args|
            require "ruby_cms/content_blocks_sync"

            locale = args[:locale].presence&.to_sym
            namespace = args[:namespace].presence ||
                        Rails.application.config.ruby_cms.content_blocks_translation_namespace
            locales_dir = RubyCms::Engine.parse_locales_dir(args[:locales_dir]) ||
                          Rails.root.join("config/locales")
            import_options = RubyCms::Engine.parse_import_options

            sync = RubyCms::ContentBlocksSync.new(namespace:, locales_dir:)
            summary = sync.import_from_yaml(locale:, **import_options)

            RubyCms::Engine.display_import_summary(summary)
          end

          desc "Sync content blocks: export DB to YAML, optionally import from YAML"
          task :sync, %i[namespace locales_dir] => :environment do |_t, args|
            require "ruby_cms/content_blocks_sync"

            namespace = args[:namespace].presence
            locales_dir = RubyCms::Engine.parse_locales_dir(args[:locales_dir])
            import_after = ENV["import_after"] == "true"

            sync = RubyCms::ContentBlocksSync.new(namespace:, locales_dir:)
            result = sync.sync(import_after_export: import_after)

            RubyCms::Engine.display_sync_summary(result, import_after)
          end
        end

        namespace :css do
          desc "Compile RubyCMS admin.css from component files (for gem development)"
          task compile_gem: :environment do
            dest = RubyCms::Engine.root.join("app/assets/stylesheets/ruby_cms/admin.css")
            RubyCms::Engine.compile_admin_css(dest)
            puts "✓ Compiled admin.css in gem" # rubocop:disable Rails/Output
          end

          desc "Compile RubyCMS CSS to host app (combines component files)"
          task compile: :environment do
            require "fileutils"
            dest_dir = Rails.root.join("app/assets/stylesheets/ruby_cms")
            FileUtils.mkdir_p(dest_dir)
            dest = dest_dir.join("admin.css")
            RubyCms::Engine.compile_admin_css(dest)
            puts "✓ Compiled admin.css to #{dest}" # rubocop:disable Rails/Output
            puts "✓ RubyCMS CSS compilation complete!" # rubocop:disable Rails/Output
          end
        end
      end
    end

    def self.grant_admin_permissions_to_admin_users
      return unless defined?(::User) && User.column_names.include?("admin")

      permission_keys = RubyCms::Permission.all_keys
      permissions = RubyCms::Permission.where(key: permission_keys).index_by(&:key)
      User.where(admin: true).find_each do |u|
        permission_keys.each do |key|
          perm = permissions[key]
          next if perm.nil?

          RubyCms::UserPermission.find_or_create_by!(user: u, permission: perm)
        end
      end
    end

    def self.extract_email_from_args(args)
      args[:email] || ENV["email"] || ENV.fetch("EMAIL", nil)
    end

    def self.validate_email_present(email)
      return if email.present?

      warn "Usage: rails ruby_cms:grant_manage_admin " \
           "email=user@example.com"
      raise "Email is required"
    end

    def self.find_user_by_email(email)
      user_class = Rails.application.config.ruby_cms.user_class_name
                        .constantize
      find_user_by_email_address(user_class, email) ||
        find_user_by_email_column(user_class, email)
    end

    def self.find_user_by_email_address(user_class, email)
      return unless user_class.column_names.include?("email_address")

      user_class.find_by(email_address: email)
    end

    def self.find_user_by_email_column(user_class, email)
      return unless user_class.column_names.include?("email")

      user_class.find_by(email:)
    end

    def self.validate_user_found(user, email)
      return if user

      warn "User not found: #{email}"
      raise "User not found: #{email}"
    end

    def self.grant_manage_admin_permission(user, email)
      RubyCms::Permission.ensure_defaults!
      RubyCms::Permission.all_keys.each do |key|
        perm = RubyCms::Permission.find_by(key:)
        next unless perm

        RubyCms::UserPermission.find_or_create_by!(user: user, permission: perm)
      end
      puts "Granted full admin permissions to #{email}" # rubocop:disable Rails/Output
    end

    def self.parse_locales_dir(locales_dir_arg)
      return nil unless locales_dir_arg.presence

      Pathname.new(locales_dir_arg)
    end

    def self.parse_import_options
      {
        create_missing: ENV["create_missing"] != "false",
        update_existing: ENV["update_existing"] != "false",
        published: ENV["published"] == "true"
      }
    end

    def self.display_export_summary(summary)
      if summary.empty?
        puts "No content blocks found to export." # rubocop:disable Rails/Output
      else
        puts "Exported content blocks to locale files:" # rubocop:disable Rails/Output
        summary.each do |locale, count|
          # rubocop:disable Rails/Output
          puts "  #{locale}: #{count} block(s) updated " \
               "in config/locales/#{locale}.yml"
          # rubocop:enable Rails/Output
        end
      end
    end

    def self.display_import_summary(summary)
      $stdout.puts "Import summary:"
      $stdout.puts "  Created: #{summary[:created]}"
      $stdout.puts "  Updated: #{summary[:updated]}"
      $stdout.puts "  Skipped: #{summary[:skipped]}"
      return unless summary[:errors].any?

      $stdout.puts "  Errors:"
      summary[:errors].each {|e| $stdout.puts "    - #{e}" }
    end

    def self.display_sync_summary(result, import_after)
      display_export_results(result[:export])
      display_import_results(result[:import], import_after) if import_after
    end

    def self.display_export_results(export_data)
      $stdout.puts "Sync complete!"
      $stdout.puts "\nExport summary:"
      export_data.each do |locale, count|
        $stdout.puts "  #{locale}: #{count} block(s) updated"
      end
    end

    def self.display_import_results(import_data, import_after)
      return unless import_after && import_data.any?

      $stdout.puts "\nImport summary:"
      $stdout.puts "  Created: #{import_data[:created]}"
      $stdout.puts "  Updated: #{import_data[:updated]}"
      $stdout.puts "  Skipped: #{import_data[:skipped]}"
    end

    initializer "ruby_cms.load_migrations" do |app|
      next unless app.config.respond_to?(:paths)

      config.paths["db/migrate"].expanded.each do |path|
        app.config.paths["db/migrate"] << path
      end
    end
  end
end
