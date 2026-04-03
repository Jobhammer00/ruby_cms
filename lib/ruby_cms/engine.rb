# frozen_string_literal: true

require_relative "settings_registry"
require_relative "settings"
require_relative "dashboard_blocks"
require_relative "engine/css"
require_relative "engine/dashboard_registration"
require_relative "engine/navigation_registration"
require_relative "engine/admin_permissions"
require_relative "engine/content_blocks_tasks"

module RubyCms
  class Engine < ::Rails::Engine
    extend RubyCms::EngineCss
    extend RubyCms::EngineDashboardRegistration
    extend RubyCms::EngineNavigationRegistration
    extend RubyCms::EngineAdminPermissions
    extend RubyCms::EngineContentBlocksTasks

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
      next if RubyCms::Engine.assets_precompile_phase?

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
        # Only sweep the engine's Stimulus tree (not the whole app/javascript tree)
        app.config.importmap.cache_sweepers << config.root.join("app/javascript/controllers/ruby_cms")
      end
    end

    initializer "ruby_cms.nav" do
      next if RubyCms::Engine.assets_precompile_phase?

      Rails.application.config.to_prepare do
        RubyCms::Engine.register_main_nav_items
        RubyCms::Engine.register_settings_nav_items
      end
    end

    initializer "ruby_cms.dashboard_blocks" do
      next if RubyCms::Engine.assets_precompile_phase?

      RubyCms::Engine.register_default_dashboard_blocks
    end

    initializer "ruby_cms.versionable" do
      next if RubyCms::Engine.assets_precompile_phase?

      Rails.application.config.to_prepare do
        ContentBlock.include(ContentBlock::Versionable) unless ContentBlock <= ContentBlock::Versionable
      end
    end

    initializer "ruby_cms.settings_import", after: :load_config_initializers do
      next if RubyCms::Engine.assets_precompile_phase?

      RubyCms::Settings.import_initializer_values!
    end

    # After host initializers (e.g. register_permission_keys), ensure Permission rows exist
    # so can?(:manage_backups) and other keys do not fail on Permission.exists? checks.
    initializer "ruby_cms.ensure_permission_rows", after: :load_config_initializers do
      next if RubyCms::Engine.assets_precompile_phase?

      RubyCms::Permission.ensure_defaults!
    rescue StandardError => e
      Rails.logger.warn("[RubyCMS] Permission.ensure_defaults! skipped: #{e.message}")
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

    initializer "ruby_cms.load_migrations" do |app|
      next unless app.config.respond_to?(:paths)

      config.paths["db/migrate"].expanded.each do |path|
        app.config.paths["db/migrate"] << path
      end
    end

    # True during asset pipeline tasks so we skip DB-heavy initializers (permissions, settings import).
    # Detect by ARGV first: $PROGRAM_NAME is often "ruby" when using `ruby bin/rails`, which would
    # miss the old rake/rails basename check; tailwindcss:build runs as a prerequisite of
    # assets:precompile and keeps the same ARGV, but a standalone `rails tailwindcss:build` must match too.
    def self.assets_precompile_phase?
      argv = Array(ARGV).map(&:to_s)
      return true if argv.include?("assets:precompile")
      return true if argv.any? {|a| a.start_with?("tailwindcss:") }
      return true if argv.include?("propshaft:compile")

      command = File.basename($PROGRAM_NAME.to_s)
      (command == "rake" || command == "rails") && argv.include?("assets:precompile")
    end
  end
end
