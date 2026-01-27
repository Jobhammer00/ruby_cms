# frozen_string_literal: true

require_relative "component_registry"
require_relative "component_registry/defaults"

module RubyCms
  class Engine < ::Rails::Engine
    # Do not isolate namespace so we can use /admin and explicit table names.
    # All engine models use explicit table_name with ruby_cms_ prefix.

    config.ruby_cms = ActiveSupport::OrderedOptions.new

    # Base controller for all /admin controllers. Must provide current_user and
    # run require_authentication (or equivalent). Default: ApplicationController.
    config.ruby_cms.admin_base_controller = "ApplicationController"
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

    # Layout for public /p/:key pages. Default: "application".
    config.ruby_cms.public_page_layout = "application"
    # Public pages: allowlist of page_key => template path for codebase-only pages (e.g. "home" => "pages/home").
    # Falls back to preview_templates if not set.
    config.ruby_cms.public_templates = nil
    # Visual editor: allowlist of page_key => template path (e.g. "home" => "pages/home").
    # Can be extended by Page model: Page.preview_templates_hash merges config with Page records.
    config.ruby_cms.preview_templates = {}
    # Proc to inject preview data: ->(page_key, view_context) { { @products => [] } }
    config.ruby_cms.preview_data = ->(_page_key, _view) { {} }
    # Optional: audit edits from the visual editor. ->(content_block_id, user_id, changes) { }
    config.ruby_cms.audit_editor_edit = nil

    # Content blocks: reserved key prefixes (e.g. "admin_") cannot be used.
    config.ruby_cms.reserved_key_prefixes = %w[admin_]
    # Content blocks: default translation namespace (e.g., "content_blocks" or "cms")
    # When set, content_block helper will try translations at namespace.key before root-level key
    # Example: If namespace is "content_blocks", it tries "content_blocks.home_hero_title" then "home_hero_title"
    config.ruby_cms.content_blocks_translation_namespace = nil
    # Image attachment: allowed content types and max size.
    config.ruby_cms.image_content_types = %w[image/png image/jpeg image/gif image/webp]
    config.ruby_cms.image_max_size = 5.megabytes

    # Component Registry: allowlist of components
    # Configure via: config.ruby_cms.component_registry.register(...)
    config.ruby_cms.component_registry = RubyCms.component_registry

    initializer "ruby_cms.i18n" do |app|
      app.config.i18n.load_path += Dir[config.root.join("config", "locales", "**", "*.yml")]
    end

    initializer "ruby_cms.helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        helper RubyCms::ApplicationHelper
        helper RubyCms::ContentBlocksHelper
        helper RubyCms::PageRendererHelper
        helper RubyCms::BulkActionTableHelper
        helper RubyCms::Admin::BulkActionTableHelper
      end
    end

    initializer "ruby_cms.assets" do |app|
      # Add JavaScript controllers to asset pipeline
      if app.config.respond_to?(:assets)
        app.config.assets.paths << config.root.join("app/javascript")
      end
      # Add stylesheets to asset pipeline
      if app.config.respond_to?(:assets)
        app.config.assets.paths << config.root.join("app/assets/stylesheets")
      end
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
        # Main content section (no section = appears after dashboard)
        RubyCms.nav_register(
          key: :dashboard,
          label: "Dashboard",
          path: lambda(&:ruby_cms_admin_root_path),
          icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>'
        )
        RubyCms.nav_register(
          key: :content_blocks,
          label: "Content blocks",
          path: lambda(&:ruby_cms_admin_content_blocks_path),
          icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"></path>'
        )
        RubyCms.nav_register(
          key: :visual_editor,
          label: "Visual editor",
          path: lambda(&:ruby_cms_admin_visual_editor_path),
          icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path>'
        )

        # Settings section
        RubyCms.nav_register(
          key: :permissions,
          label: "Permissions",
          path: lambda(&:ruby_cms_admin_permissions_path),
          section: "Settings",
          icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path>'
        )
        RubyCms.nav_register(
          key: :users,
          label: "Users",
          path: lambda(&:ruby_cms_admin_users_path),
          section: "Settings",
          icon: '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>'
        )
      end
    end

    initializer "ruby_cms.component_registry" do
      Rails.application.config.to_prepare do
        RubyCms::ComponentRegistry::Defaults.register_all
      end
    end

    config.paths.add "db/migrate", with: "db/migrate"

    rake_tasks do
      namespace :ruby_cms do
        desc "Create default permissions and optionally grant manage_admin to admin users"
        task seed_permissions: :environment do
          RubyCms::Permission.ensure_defaults!
          if defined?(::User) && User.column_names.include?("admin")
            perm = RubyCms::Permission.find_by!(key: "manage_admin")
            User.where(admin: true).find_each do |u|
              RubyCms::UserPermission.find_or_create_by!(user: u, permission: perm)
            end
          end
        end

        desc "Interactively create or select the first admin user and grant full permissions (manage_admin, manage_permissions, manage_content_blocks, etc.)"
        task setup_admin: :environment do
          require "ruby_cms/cli"
          RubyCms::RunSetupAdmin.call(shell: Thor::Shell::Basic.new)
        end

        desc "Grant manage_admin to a user by email. Usage: rails ruby_cms:grant_manage_admin email=user@example.com"
        task :grant_manage_admin, [:email] => :environment do |_t, args|
          email = args[:email] || ENV["email"] || ENV.fetch("EMAIL", nil)
          abort "Usage: rails ruby_cms:grant_manage_admin email=user@example.com" if email.blank?

          RubyCms::Permission.ensure_defaults!
          user_class = Rails.application.config.ruby_cms.user_class_name.constantize
          user = nil
          if user_class.column_names.include?("email_address")
            user = user_class.find_by(email_address: email)
          end
          if user.nil? && user_class.column_names.include?("email")
            user ||= user_class.find_by(email:)
          end
          abort "User not found: #{email}" unless user

          perm = RubyCms::Permission.find_by!(key: "manage_admin")
          RubyCms::UserPermission.find_or_create_by!(user: user, permission: perm)
          $stdout.puts "Granted manage_admin to #{email}"
        end

        namespace :content_blocks do
          desc "Export content blocks from database to YAML locale files"
          task :export, %i[namespace locales_dir] => :environment do |_t, args|
            require "ruby_cms/content_blocks_sync"

            namespace = args[:namespace]&.presence
            locales_dir = args[:locales_dir]&.presence ? Pathname.new(args[:locales_dir]) : nil
            flatten = ENV["flatten"] == "true"

            sync = RubyCms::ContentBlocksSync.new(namespace:, locales_dir:)
            summary = sync.export_to_yaml(only_published: true, flatten_keys: flatten)

            if summary.empty?
              $stdout.puts "No content blocks found to export."
            else
              $stdout.puts "Exported content blocks to locale files:"
              summary.each do |locale, count|
                $stdout.puts "  #{locale}: #{count} block(s) updated in config/locales/#{locale}.yml"
              end
            end
          end

          desc "Import content blocks from YAML locale files to database"
          task :import, %i[locale namespace locales_dir] => :environment do |_t, args|
            require "ruby_cms/content_blocks_sync"

            locale = args[:locale]&.presence&.to_sym
            namespace = args[:namespace]&.presence
            locales_dir = args[:locales_dir]&.presence ? Pathname.new(args[:locales_dir]) : nil
            create_missing = ENV["create_missing"] != "false"
            update_existing = ENV["update_existing"] != "false"
            published = ENV["published"] == "true"

            sync = RubyCms::ContentBlocksSync.new(namespace:, locales_dir:)
            summary = sync.import_from_yaml(
              locale:,
              create_missing:,
              update_existing:,
              published:
            )

            $stdout.puts "Import summary:"
            $stdout.puts "  Created: #{summary[:created]}"
            $stdout.puts "  Updated: #{summary[:updated]}"
            $stdout.puts "  Skipped: #{summary[:skipped]}"
            if summary[:errors].any?
              $stdout.puts "  Errors:"
              summary[:errors].each {|e| $stdout.puts "    - #{e}" }
            end
          end

          desc "Sync content blocks: export DB to YAML, optionally import from YAML"
          task :sync, %i[namespace locales_dir] => :environment do |_t, args|
            require "ruby_cms/content_blocks_sync"

            namespace = args[:namespace]&.presence
            locales_dir = args[:locales_dir]&.presence ? Pathname.new(args[:locales_dir]) : nil
            import_after = ENV["import_after"] == "true"

            sync = RubyCms::ContentBlocksSync.new(namespace:, locales_dir:)
            result = sync.sync(import_after_export: import_after)

            $stdout.puts "Sync complete!"
            $stdout.puts "\nExport summary:"
            result[:export].each do |locale, count|
              $stdout.puts "  #{locale}: #{count} block(s) updated"
            end

            if import_after && result[:import].any?
              $stdout.puts "\nImport summary:"
              $stdout.puts "  Created: #{result[:import][:created]}"
              $stdout.puts "  Updated: #{result[:import][:updated]}"
              $stdout.puts "  Skipped: #{result[:import][:skipped]}"
            end
          end
        end
      end
    end

    initializer "ruby_cms.load_migrations" do |app|
      next unless app.config.respond_to?(:paths)

      config.paths["db/migrate"].expanded.each do |path|
        app.config.paths["db/migrate"] << path
      end
    end
  end
end
