# frozen_string_literal: true

require "fileutils"

module RubyCms
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      NEXT_STEPS_MESSAGE = <<~TEXT

        ✓ RubyCMS install complete.

        Next steps (if not already done):
        - rails db:migrate
        - rails ruby_cms:seed_permissions (includes manage_visitor_errors and manage_analytics)
        - rails ruby_cms:setup_admin (or: rails ruby_cms:grant_manage_admin email=you@example.com)
        - To seed content blocks from YAML: add content under content_blocks in config/locales/<locale>.yml, then run rails ruby_cms:content_blocks:seed (or call it from db/seeds.rb).

        Notes:
        - If the host uses /admin already, remove or change those routes.
        - Avoid root to: redirect("/admin") — use a real root or ruby_cms.unauthorized_redirect_path.
        - Review config/initializers/ruby_cms.rb (session, CSP).
        - Add 'css: bin/rails tailwindcss:watch' to Procfile.dev for Tailwind in development.
        - Visit /admin (sign in as the admin you configured).

        Tracking:
        - Visitor errors: Automatically captured via ApplicationController (see /admin/visitor_errors)
        - Page views (Ahoy): Include RubyCms::PageTracking in your public controllers to track page views
          Example: class PagesController < ApplicationController; include RubyCms::PageTracking; end
        - Analytics: View visit/event data in Ahoy tables (ahoy_visits, ahoy_events)
      TEXT

      def run_authentication
        user_path = Rails.root.join("app/models/user.rb")
        return if File.exist?(user_path)

        say "ℹ Task authentication: User model not found. " \
            "Running 'rails g authentication' (Rails 8+).", :cyan
        @authentication_attempted = true
        run "bin/rails generate authentication"
        run "bundle install"
      rescue StandardError => e
        say "⚠ Could not run 'rails g authentication': #{e.message}.", :yellow
        say "   On Rails 8+, run 'rails g authentication' and 'bundle install' manually.", :yellow
      end

      def verify_auth
        verify_user_model
        verify_session_model
        verify_application_controller
      end

      def verify_user_model
        return if defined?(::User)

        message = if @authentication_attempted
                    "Run 'rails db:migrate' if the authentication generator succeeded."
                  else
                    "User model not found. Run 'rails g authentication' before using /admin."
                  end
        say "ℹ Task authentication: #{message}", :yellow
      end

      def verify_session_model
        return if defined?(::Session)

        say "ℹ Task authentication: Session model not found. " \
            "The host app should provide authentication.",
            :yellow
      end

      def verify_application_controller
        ac_path = Rails.root.join("app/controllers/application_controller.rb")
        return unless ac_path.exist?

        content = File.read(ac_path)
        return if content.include?("include Authentication")
        return if @authentication_warning_shown

        say "ℹ Task authentication: ApplicationController does not include " \
            "Authentication. Ensure /admin is protected.",
            :yellow
        @authentication_warning_shown = true
      end

      def create_initializer
        @detected_pages = detect_page_templates
        template "ruby_cms.rb", "config/initializers/ruby_cms.rb"
      end

      def mount_engine
        route 'mount RubyCms::Engine => "/"'
      end

      def add_catch_all_route
        routes_path = Rails.root.join("config/routes.rb")
        return unless routes_path.exist?

        content = File.read(routes_path)
        return if content.include?("ruby_cms/errors#not_found")

        # Add catch-all route at the end of the routes block (before final 'end')
        catch_all = <<~ROUTE

          # RubyCMS: Catch-all route for 404 error tracking (must be LAST)
          match "*path", to: "ruby_cms/errors#not_found", via: :all,
                constraints: ->(req) { !req.path.start_with?("/rails/", "/assets/") }
        ROUTE

        # Insert before the last 'end' in the file
        gsub_file routes_path, /(\nend)\s*\z/ do
          "#{catch_all}end\n"
        end
        say "✓ Catch-all route: Added for 404 error tracking", :green
      rescue StandardError => e
        say "⚠ Catch-all route: Could not add automatically: #{e.message}. " \
            "Add manually at the END of routes.rb:\n  " \
            'match "*path", to: "ruby_cms/errors#not_found", via: :all, ' \
            'constraints: ->(req) { !req.path.start_with?("/rails/", "/assets/") }',
            :yellow
      end

      def add_permittable_to_user
        user_path = Rails.root.join("app/models/user.rb")
        unless File.exist?(user_path)
          say "Skipping User: app/models/user.rb not found.", :yellow
          return
        end

        return if File.read(user_path).include?("RubyCms::Permittable")

        inject_into_file user_path, after: /class User .*\n/ do
          "  include RubyCms::Permittable\n"
        end
      end

      def add_current_user_to_authentication
        auth_path = Rails.root.join("app/controllers/concerns/authentication.rb")
        return unless auth_path.exist?
        return if File.read(auth_path).include?("def current_user")

        gsub_file auth_path, "    helper_method :authenticated?\n",
                  "    helper_method :authenticated?, :current_user\n"
        inject_into_file auth_path, after: "  private\n" do
          "    def current_user\n      Current.user\n    end\n\n"
        end
      end

      def add_visitor_error_capture
        ac_path = Rails.root.join("app/controllers/application_controller.rb")
        return unless ac_path.exist?

        content = File.read(ac_path)
        return if content.include?("RubyCms::VisitorErrorCapture")

        to_inject = "  include RubyCms::VisitorErrorCapture\n"
        to_inject += "  rescue_from StandardError, with: :handle_visitor_error\n" \
          unless content.include?("rescue_from StandardError")

        inject_into_file ac_path, after: /class ApplicationController.*\n/ do
          to_inject
        end
        say "✓ Visitor error capture: Added to ApplicationController", :green
      rescue StandardError => e
        say "⚠ Visitor error capture: Could not add to ApplicationController: #{e.message}. " \
            "Add manually: include RubyCms::VisitorErrorCapture and rescue_from StandardError, with: :handle_visitor_error",
            :yellow
      end

      def add_page_tracking_to_home_controller
        home_path = Rails.root.join("app/controllers/home_controller.rb")
        return unless home_path.exist?

        content = File.read(home_path)
        return if content.include?("RubyCms::PageTracking")

        inject_into_file home_path, after: /class HomeController.*\n/ do
          "  include RubyCms::PageTracking\n"
        end

        say "✓ Page tracking: Added RubyCms::PageTracking to HomeController", :green
      rescue StandardError => e
        say "⚠ Page tracking: Could not add to HomeController: #{e.message}. " \
            "Add manually: include RubyCms::PageTracking",
            :yellow
      end

      def copy_fallback_css
        src_dir = RubyCms::Engine.root.join("app/assets/stylesheets/ruby_cms")
        dest_dir = Rails.root.join("app/assets/stylesheets/ruby_cms")

        return unless src_dir.exist?

        FileUtils.mkdir_p(dest_dir)
        copy_admin_css(dest_dir)
        # Don't copy component files - only the compiled admin.css is needed
        # copy_components_css(src_dir, dest_dir)
        say "✓ Task css/copy: Combined component CSS into " \
            "app/assets/stylesheets/ruby_cms/admin.css", :green
      rescue StandardError => e
        say "⚠ Task css/copy: Could not copy CSS files: #{e.message}.", :yellow
      end

      def create_admin_layout
        layout_path = Rails.root.join("app/views/layouts/admin.html.erb")
        return if File.exist?(layout_path)

        template "admin.html.erb", layout_path.to_s
        say "✓ Layout admin: Created app/views/layouts/admin.html.erb", :green
      rescue StandardError => e
        say "⚠ Layout admin: Could not create admin.html.erb: #{e.message}. " \
            "Create it manually using the RubyCMS template.", :yellow
      end
      no_tasks do
        def copy_admin_css(dest_dir)
          admin_css_dest = dest_dir.join("admin.css")
          RubyCms::Engine.compile_admin_css(admin_css_dest)
        end

        def copy_components_css(src_dir, dest_dir)
          components_src_dir = src_dir.join("components")
          components_dest_dir = dest_dir.join("components")
          return unless components_src_dir.exist? && components_src_dir.directory?

          FileUtils.mkdir_p(components_dest_dir)
          Dir.glob(components_src_dir.join("*.css")).each do |src_file|
            copy_component_css_file(src_file, components_dest_dir)
          end
        end

        def copy_component_css_file(src_file, dest_dir)
          filename = File.basename(src_file)
          dest_file = dest_dir.join(filename)
          return if dest_file.exist? && File.mtime(src_file) <= File.mtime(dest_file)

          FileUtils.cp(src_file, dest_file, preserve: true)
        end
      end

      def install_ahoy
        if ahoy_already_installed?
          say "ℹ Task ahoy: Existing Ahoy setup detected (tables or migrations). Skipping ahoy:install.",
              :cyan
          configure_ahoy_server_side_only
          return
        end

        say "ℹ Task ahoy: Installing Ahoy for visit/event tracking.", :cyan
        run "bin/rails generate ahoy:install"
        add_ahoy_security_fields_migration
        configure_ahoy_server_side_only
        say "✓ Task ahoy: Installed Ahoy (visits, events, tracking)", :green
      rescue StandardError => e
        say "⚠ Task ahoy: Could not install: #{e.message}. " \
            "Run 'rails g ahoy:install' manually.",
            :yellow
      end

      def install_action_text
        migrate_dir = Rails.root.join("db/migrate")
        return unless migrate_dir.directory?
        return if action_text_already_installed?(migrate_dir)

        say "ℹ Task action_text: Installing Action Text for rich text/image content blocks.", :cyan
        run "bin/rails action_text:install"
        say "✓ Task action_text: Installed Action Text", :green
      rescue StandardError => e
        say "⚠ Task action_text: Could not install: #{e.message}. Rich text will be disabled.",
            :yellow
      end

      no_tasks do
        def ahoy_already_installed?
          return true if ahoy_tables_exist?

          migrate_dir = Rails.root.join("db/migrate")
          return false unless migrate_dir.directory?

          Dir.glob(migrate_dir.join("*.rb").to_s).any? do |f|
            content = File.read(f)
            content.include?("ahoy_visits") || content.include?("ahoy_events")
          end
        end

        def ahoy_tables_exist?
          return false unless defined?(ActiveRecord::Base)

          # Calling connection lazily establishes a connection when possible,
          # so we can detect existing Ahoy tables even before AR reports connected?.
          c = ActiveRecord::Base.connection
          c.data_source_exists?("ahoy_visits") || c.data_source_exists?("ahoy_events")
        rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError,
               ActiveRecord::StatementInvalid
          false
        end

        def add_ahoy_security_fields_migration
          run "bin/rails generate migration AddRubyCmsFieldsToAhoyEvents"
          migration_file = Rails.root.glob("db/migrate/*add_ruby_cms*fields*.rb").max_by(&:basename)
          return unless migration_file

          migration_file = migration_file.to_s
          content = <<~RUBY
            class AddRubyCmsFieldsToAhoyEvents < ActiveRecord::Migration[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]
              def change
                return unless table_exists?(:ahoy_events)

                add_column :ahoy_events, :page_name, :string unless column_exists?(:ahoy_events, :page_name)
                add_column :ahoy_events, :ip_address, :string unless column_exists?(:ahoy_events, :ip_address)
                add_column :ahoy_events, :request_path, :string unless column_exists?(:ahoy_events, :request_path)
                add_column :ahoy_events, :user_agent, :text unless column_exists?(:ahoy_events, :user_agent)
                add_column :ahoy_events, :description, :text unless column_exists?(:ahoy_events, :description)

                add_index :ahoy_events, :page_name, if_not_exists: true
                add_index :ahoy_events, :ip_address, if_not_exists: true
                add_index :ahoy_events, :request_path, if_not_exists: true
                add_index :ahoy_events, [:name, :page_name], if_not_exists: true
                add_index :ahoy_events, [:name, :request_path], if_not_exists: true
              end
            end
          RUBY
          File.write(migration_file, content)
        end

        def configure_ahoy_server_side_only
          ahoy_path = Rails.root.join("config/initializers/ahoy.rb")
          content = if ahoy_path.exist?
                      File.read(ahoy_path)
                    else
                      <<~RUBY
                        # Configure Ahoy
                      RUBY
                    end

          # Ensure Ahoy is loaded before any references (fixes NameError when
          # ahoy_matey loads after initializers)
          content = %(require "ahoy_matey"\n\n#{content}) unless content.include?('require "ahoy_matey"')

          # Ensure a default Ahoy store class exists.
          unless content.match?(/class\s+Ahoy::Store\s*<\s*Ahoy::DatabaseStore/)
            content += <<~RUBY

              class Ahoy::Store < Ahoy::DatabaseStore
              end
            RUBY
          end

          if content.include?("Ahoy.api = false")
            File.write(ahoy_path, content)
            return
          end

          append = "\n\n# RubyCMS: server-side tracking only (no JavaScript)\nAhoy.api = false\nAhoy.geocode = false\n"
          File.write(ahoy_path, "#{content}#{append}")
        end

        def action_text_already_installed?(migrate_dir)
          return true if active_storage_tables_exist? || action_text_tables_exist?

          existing = Dir.glob(migrate_dir.join("*.rb").to_s).join("\n")
          existing.include?("create_action_text_rich_texts") ||
            existing.include?("create_active_storage_tables")
        end

        def active_storage_tables_exist?
          return false unless defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?

          c = ActiveRecord::Base.connection
          c.data_source_exists?("active_storage_blobs") &&
            c.data_source_exists?("active_storage_attachments")
        rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError
          false
        end

        def action_text_tables_exist?
          return false unless defined?(ActiveRecord::Base) && ActiveRecord::Base.connected?

          ActiveRecord::Base.connection.data_source_exists?("action_text_rich_texts")
        rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError
          false
        end
      end

      def install_tailwind
        gemfile = Rails.root.join("Gemfile")
        tailwind_css = detect_tailwind_entry_css_path

        install_tailwind_if_needed(gemfile, tailwind_css)
        configure_tailwind(tailwind_css)
      rescue StandardError => e
        say "⚠ Task tailwind: Could not install: #{e.message}. Add tailwindcss-rails manually.",
            :yellow
      end

      no_tasks do
        def detect_tailwind_entry_css_path
          candidates = [
            Rails.root.join("app/assets/tailwind/application.css"),
            Rails.root.join("app/assets/stylesheets/application.tailwind.css"),
            Rails.root.join("app/assets/stylesheets/tailwind.css")
          ]
          candidates.find(&:exist?) || candidates.first
        end

        def install_tailwind_if_needed(gemfile, tailwind_css)
          return if File.exist?(tailwind_css)

          if File.read(gemfile).include?("tailwindcss-rails")
            say "ℹ Task tailwind: Tailwind CSS gem found; running tailwindcss:install.", :cyan
          else
            say "ℹ Task tailwind: Adding tailwindcss-rails for admin styling.", :cyan
            run "bundle add tailwindcss-rails"
          end
          run "bin/rails tailwindcss:install"
          say "✓ Task tailwind: Installed Tailwind CSS", :green
        end

        def configure_tailwind(tailwind_css)
          add_ruby_cms_tailwind_source(tailwind_css)
          add_ruby_cms_tailwind_content_paths
          run "bin/rails tailwindcss:build" if File.exist?(tailwind_css)
          # Importmap pins are provided by the engine via `ruby_cms/config/importmap.rb`.
          add_importmap_pins
          add_stimulus_registration
        end
      end

      def install_ruby_ui
        gemfile = Rails.root.join("Gemfile")
        gemfile_content = File.read(gemfile)
        return if ruby_ui_in_gemfile?(gemfile_content)

        add_ruby_ui_gem
      rescue StandardError => e
        say "⚠ Task ruby_ui: Could not add: #{e.message}. " \
            "Run 'bundle add ruby_ui --group development --require false' manually.",
            :yellow
        nil
      end

      def run_ruby_ui_install
        gemfile = Rails.root.join("Gemfile")
        gemfile_content = File.read(gemfile)
        return unless ruby_ui_in_gemfile?(gemfile_content)
        return if ruby_ui_already_installed?

        install_ruby_ui_generator
      end

      no_tasks do
        def ruby_ui_in_gemfile?(content)
          content.include?("ruby_ui") || content.include?("rails_ui")
        end

        def add_ruby_ui_gem
          say "ℹ Task ruby_ui: Adding ruby_ui to Gemfile.", :cyan
          run "bundle add ruby_ui --group development --require false"
          run "bundle install"
          say "✓ Task ruby_ui: Added ruby_ui to Gemfile", :green
        end

        def ruby_ui_already_installed?
          ruby_ui_initializer = Rails.root.join("config/initializers/ruby_ui.rb")
          ruby_ui_base = Rails.root.join("app/components/ruby_ui/base.rb")
          if File.exist?(ruby_ui_initializer) || File.exist?(ruby_ui_base)
            say "ℹ Task ruby_ui:install: ruby_ui is already installed. Skipping.", :cyan
            return true
          end
          false
        end

        def install_ruby_ui_generator
          say "ℹ Task ruby_ui:install: Running ruby_ui:install generator.", :cyan
          try_ruby_ui_install
        rescue StandardError => e
          say "⚠ Task ruby_ui:install: Could not find generator: #{e.message}. " \
              "Run 'rails g ruby_ui:install' manually.",
              :yellow
        end

        def try_ruby_ui_install
          run "bin/rails generate ruby_ui:install"
          say "✓ Task ruby_ui:install: Installed ruby_ui", :green
        rescue StandardError
          try_rails_ui_install
        end

        def try_rails_ui_install
          say "ℹ Task ruby_ui:install: Using rails_ui:install (ruby_ui alias).", :cyan
          run "bin/rails generate rails_ui:install"
          say "✓ Task ruby_ui:install: Installed rails_ui", :green
        end

        def add_ruby_ui_to_application_helper
          helper_path = Rails.root.join("app/helpers/application_helper.rb")
          return unless File.exist?(helper_path)

          content = File.read(helper_path)
          return if ruby_ui_already_included?(content)

          inject_ruby_ui_include(helper_path)
        rescue StandardError => e
          say "⚠ Task ruby_ui/helper: Could not add RubyUI: #{e.message}. " \
              "Add 'include RubyUI' manually.",
              :yellow
        end

        def ruby_ui_already_included?(content)
          content.include?("include RubyUI") || content.include?("include RubyUi")
        end

        def inject_ruby_ui_include(helper_path)
          say "✓ Task ruby_ui/helper: Added include RubyUI to ApplicationHelper.", :green
          inject_into_file helper_path.to_s, after: /module ApplicationHelper\n/ do
            "  include RubyUI\n"
          end
        end

        def generate_ruby_ui_components
          # Skip component generation - page builder removed.
          # Generate manually: rails g ruby_ui:component ComponentName
          say "ℹ Task ruby_ui/components: Skipping automatic component generation " \
              "(page builder removed). " \
              "Generate components manually if needed: rails g ruby_ui:component ComponentName",
              :cyan
        end
      end

      # Directories to skip when scanning for page templates
      SKIP_VIEW_DIRS = %w[layouts shared mailers components admin].freeze

      # NOTE: Rails generators are Thor groups; private methods can still be
      # treated as "tasks" unless wrapped in `no_tasks`.
      no_tasks do
        def detect_page_templates
          views_dir = Rails.root.join("app/views")
          return {} unless Dir.exist?(views_dir)

          pages = {}
          views_base = views_dir.to_s
          scan_for_templates(views_dir, pages, views_base)
          log_detected_pages(pages) if pages.any?
          pages
        rescue StandardError => e
          say "⚠ Task pages: Could not scan for page templates: #{e.message}.", :yellow
          {}
        end

        def scan_for_templates(dir_path, pages, views_base, relative_path="")
          # Find all template files in this directory
          Dir.glob(File.join(dir_path, "*.{html.erb,html.haml,html.slim}")).each do |template_file|
            base_name = File.basename(template_file, ".*")
            base_name = File.basename(base_name, ".*") # Remove .html extension

            # Skip partials
            next if base_name.start_with?("_")
            # Skip admin pages
            next if relative_path.start_with?("admin") || relative_path == "admin"

            # Build template path relative to app/views
            if relative_path.empty?
              template_path = base_name
              page_key = base_name
            elsif base_name == "index"
              page_key = relative_path.split("/").last
              template_path = "#{relative_path}/index"
            # pages/index.html.erb -> "pages" => "pages/index"
            else
              # pages/home.html.erb -> "home" => "pages/home"
              page_key = base_name
              template_path = "#{relative_path}/#{base_name}"
            end

            pages[page_key] = template_path
          end

          # Recursively scan subdirectories (skip common non-page dirs, limit depth)
          Dir.glob(File.join(dir_path, "*")).each do |path|
            next unless File.directory?(path)

            dir_name = File.basename(path)
            # Skip admin directories and common non-page directories
            next if SKIP_VIEW_DIRS.include?(dir_name)
            # Skip if we're already in an admin path
            next if relative_path.start_with?("admin")

            # Limit depth to 2 levels (e.g., app/views/pages/home is OK, but not deeper)
            depth = relative_path.empty? ? 1 : relative_path.split("/").length + 1
            next if depth > 2

            new_relative_path = relative_path.empty? ? dir_name : "#{relative_path}/#{dir_name}"
            scan_for_templates(path, pages, views_base, new_relative_path)
          end
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

        def log_detected_pages(pages)
          say "✓ Task pages: Detected #{pages.size} page template(s): " \
              "#{pages.keys.join(', ')}", :green
        end

        def add_importmap_pins
          importmap_path = Rails.root.join("config/importmap.rb")
          return unless File.exist?(importmap_path)

          content = File.read(importmap_path)
          gem_js_path = calculate_gem_js_path
          return if importmap_already_configured?(content, gem_js_path)

          inject_importmap_pins(importmap_path, gem_js_path)
        rescue StandardError => e
          say "⚠ Task importmap: Could not add pins: #{e.message}. " \
              "Add manually to config/importmap.rb.",
              :yellow
        end

        def calculate_gem_js_path
          RubyCms::Engine.root.join("app/javascript").relative_path_from(Rails.root).to_s
        end

        def importmap_already_configured?(content, gem_js_path)
          pin_pattern = %(pin_all_from "#{gem_js_path}/controllers", under: "controllers")
          content.include?("RubyCMS Stimulus controllers") || content.include?(pin_pattern)
        end

        def inject_importmap_pins(importmap_path, gem_js_path)
          pin_line = %(pin_all_from "#{gem_js_path}/controllers", under: "controllers")
          alias_line = %(pin "ruby_cms", to: "controllers/ruby_cms/index.js", preload: true)
          inject_into_file importmap_path.to_s, before: /^end/ do
            "\n  # RubyCMS Stimulus controllers\n  #{pin_line}\n  #{alias_line}\n"
          end
          say "✓ Task importmap: Added RubyCMS controllers to importmap.rb.", :green
        end

        def add_stimulus_registration
          controllers_app_path = Rails.root.join("app/javascript/controllers/application.js")
          return handle_missing_stimulus_file unless File.exist?(controllers_app_path)

          content = File.read(controllers_app_path)
          unless stimulus_already_exposed?(content)
            expose_stimulus_application(controllers_app_path,
                                        content)
          end
          import_rubycms_controllers(controllers_app_path, content)
          cleanup_old_registration_code
        end

        def handle_missing_stimulus_file
          say "⚠ Task stimulus: Could not find app/javascript/controllers/application.js. " \
              "RubyCMS controllers may need manual setup.",
              :yellow
        end

        def stimulus_already_exposed?(content)
          if content.include?("window.Stimulus") || content.include?("window.application")
            say "ℹ Task stimulus: Stimulus application is already exposed on window.", :cyan
            return true
          end
          false
        end

        def expose_stimulus_application(controllers_app_path, content)
          return unless stimulus_application_startable?(content)

          if stimulus_const_assignment?(content)
            add_stimulus_const_pattern(controllers_app_path)
          elsif stimulus_var_assignment?(content)
            add_stimulus_var_pattern(controllers_app_path)
          else
            warn_manual_stimulus_exposure
          end
        end

        def stimulus_application_startable?(content)
          content.include?("const application") && content.include?("Application.start")
        end

        def stimulus_const_assignment?(content)
          content.match?(/const\s+application\s*=\s*Application\.start\(\)/)
        end

        def stimulus_var_assignment?(content)
          content.match?(/application\s*=\s*Application\.start\(\)/)
        end

        def warn_manual_stimulus_exposure
          say "⚠ Task stimulus: Could not automatically expose. " \
              "Manually add 'window.Stimulus = application'.",
              :yellow
        end

        def add_stimulus_const_pattern(controllers_app_path)
          gsub_file controllers_app_path.to_s,
                    /const\s+application\s*=\s*Application\.start\(\)/,
                    "const application = Application.start()\nwindow.Stimulus = application"
          say_stimulus_added
        end

        def add_stimulus_var_pattern(controllers_app_path)
          gsub_file controllers_app_path.to_s,
                    /application\s*=\s*Application\.start\(\)/,
                    "application = Application.start()\nwindow.Stimulus = application"
          say_stimulus_added
        end

        def say_stimulus_added
          say "✓ Task stimulus: Added window.Stimulus = application to " \
              "controllers/application.js.",
              :green
        end

        # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
        def import_rubycms_controllers(controllers_app_path, content)
          # Re-read content in case it was modified by expose_stimulus_application
          content = File.read(controllers_app_path) if File.exist?(controllers_app_path)

          return if content.include?('import "ruby_cms"') || content.include?("import 'ruby_cms'")
          return if content.include?("registerRubyCmsControllers")

          # Try to add after the Stimulus import (most common pattern)
          stimulus_import_pattern = %r{import\s+.*@hotwired/stimulus.*$}
          if content.match?(stimulus_import_pattern)
            inject_into_file controllers_app_path.to_s,
                             after: stimulus_import_pattern,
                             verbose: false do
              "\nimport \"ruby_cms\""
            end
            say "✓ Task stimulus: Added RubyCMS controllers import.", :green
            return
          end

          # Try to add after any import statement
          first_import_pattern = /^import\s+.*$/m
          if content.match?(first_import_pattern)
            inject_into_file controllers_app_path.to_s,
                             after: first_import_pattern,
                             verbose: false do
              "\nimport \"ruby_cms\""
            end
            say "✓ Task stimulus: Added RubyCMS controllers import.", :green
            return
          end

          # Add at the very top if no imports found
          prepend_to_file controllers_app_path.to_s, "import \"ruby_cms\"\n"
          say "✓ Task stimulus: Added RubyCMS controllers import.", :green
        rescue StandardError => e
          say "⚠ Task stimulus: Could not add RubyCMS import: #{e.message}. " \
              "Add 'import \"ruby_cms\"' manually to controllers/application.js.",
              :yellow
        end
        # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

        def cleanup_old_registration_code
          js_files = find_js_files_to_check
          js_files.each {|js_file| cleanup_file_registration(js_file) }
        rescue StandardError
          # Silent fail - not critical
        end

        def find_js_files_to_check
          [
            Rails.root.join("app/javascript/application.js"),
            Rails.root.join("app/javascript/index.js"),
            Rails.root.join("app/javascript/entrypoints/application.js")
          ].select(&:exist?)
        end

        def cleanup_file_registration(js_file)
          content = File.read(js_file)
          return unless needs_cleanup?(content)

          new_content = remove_registration_lines(content)
          return if new_content == content

          File.write(js_file, new_content)
          say "✓ Task stimulus: Removed old manual registration from #{js_file.basename}. " \
              "Auto-registration handles this now.",
              :green
        end

        def needs_cleanup?(content)
          content.include?("registerRubyCmsControllers(application)") &&
            content.exclude?("if (typeof application !== \"undefined\")")
        end

        def remove_registration_lines(content)
          lines = content.split("\n")
          lines.reject do |line|
            line.strip.include?("registerRubyCmsControllers(application)") ||
              (line.strip.start_with?("import") && line.include?("registerRubyCmsControllers") &&
                line.include?("ruby_cms"))
          end.join("\n")
        end

        # Helper: add @source for RubyCMS views/components so Tailwind finds utility classes.
        # Not a generator task.
        def add_ruby_cms_tailwind_source(tailwind_css_path)
          return unless tailwind_css_path.to_s.present? && File.exist?(tailwind_css_path)

          content = File.read(tailwind_css_path)
          gem_source_lines = build_gem_source_lines(tailwind_css_path)
          return if gem_source_lines.all? {|line| content.include?(line) }

          inject_tailwind_source(tailwind_css_path, content, gem_source_lines)
        rescue StandardError => e
          say "⚠ Task tailwind/source: Could not add @source: #{e.message}. Add manually.", :yellow
        end

        # Tailwind v3 support (tailwind.config.js content array)
        def add_ruby_cms_tailwind_content_paths # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
          config_path = Rails.root.join("config/tailwind.config.js")
          return unless File.exist?(config_path)

          content = File.read(config_path)
          patterns = ruby_cms_tailwind_content_patterns
          return if patterns.all? {|p| content.include?(p) }

          inject = "#{patterns.map {|p| "    \"#{p}\"," }.join("\n")}\n"

          # Insert inside `content: [` if present; otherwise no-op.
          inserted = false
          if content.match?(/content:\s*\[/)
            gsub_file config_path.to_s, /content:\s*\[\s*\n/ do |match|
              inserted = true
              "#{match}#{inject}"
            end
          end

          return unless inserted

          say "✓ Task tailwind/content: Added RubyCMS paths to config/tailwind.config.js.", :green
        rescue StandardError => e
          say "⚠ Task tailwind/content: Could not update tailwind.config.js: #{e.message}.", :yellow
        end

        def ruby_cms_tailwind_content_patterns
          views = RubyCms::Engine.root.join("app/views").relative_path_from(Rails.root).to_s
          components = RubyCms::Engine.root.join("app/components").relative_path_from(Rails.root).to_s
          [
            "#{views}/**/*.erb",
            "#{components}/**/*.rb"
          ]
        end

        def build_gem_source_lines(tailwind_css_path)
          css_dir = Pathname.new(tailwind_css_path).dirname
          gem_views = path_relative_to_css_or_absolute(RubyCms::Engine.root.join("app/views"),
                                                       css_dir)
          gem_components = path_relative_to_css_or_absolute(
            RubyCms::Engine.root.join("app/components"), css_dir
          )
          [
            %(@source "#{gem_views}/**/*.erb";),
            %(@source "#{gem_components}/**/*.rb";)
          ]
        end

        def path_relative_to_css_or_absolute(target_path, css_dir)
          Pathname.new(target_path).relative_path_from(css_dir).to_s
        rescue ArgumentError
          # Different mount/volume: fall back to absolute path.
          Pathname.new(target_path).to_s
        end

        def inject_tailwind_source(tailwind_css_path, content, gem_source_lines)
          to_inject = build_tailwind_source_injection(gem_source_lines)
          inserted = try_insert_after_patterns?(tailwind_css_path, content, to_inject)
          inject_at_start(tailwind_css_path, to_inject) unless inserted
          say "✓ Task tailwind/source: Added @source for RubyCMS views/components to " \
              "tailwind/application.css.",
              :green
        end

        def build_tailwind_source_injection(gem_source_lines)
          to_inject = +"\n/* Include RubyCMS views/components so Tailwind finds utility classes. */\n"
          Array(gem_source_lines).each {|line| to_inject << line << "\n" }
          to_inject << "\n"
          to_inject
        end

        def try_insert_after_patterns?(tailwind_css_path, content, to_inject)
          patterns = [
            %(@import "tailwindcss";\n),
            %(@import "tailwindcss";),
            %(@import "tailwindcss"\n),
            %(@import "tailwindcss")
          ]
          patterns.each do |after_pattern|
            next unless content.include?(after_pattern)

            inject_into_file tailwind_css_path.to_s, after: after_pattern do
              to_inject
            end
            return true
          end
          false
        end

        def inject_at_start(tailwind_css_path, to_inject)
          inject_into_file tailwind_css_path.to_s, after: /\A/ do
            to_inject
          end
        end
      end

      def run_migrate
        say "ℹ Task db:migrate: Running db:migrate.", :cyan
        success = run("bin/rails db:migrate")
        raise "db:migrate failed" unless success

        say "✓ Task db:migrate: Completed", :green
      rescue StandardError => e
        say "⚠ Task db:migrate: Failed: #{e.message}. Run rails db:create db:migrate if needed.",
            :yellow
      end

      def run_seed_permissions
        say "ℹ Task permissions: Seeding RubyCMS permissions.", :cyan
        success = seed_permissions_via_open3
        say_seed_permissions_outcome(success)
      rescue StandardError => e
        say_seed_permissions_error(e)
      end

      def run_setup_admin
        return if skip_setup_admin_due_to_existing_admin?
        return unless setup_admin_tty?

        run_setup_admin_task
      rescue StandardError => e
        say_setup_admin_error(e)
      end

      no_tasks do
        def seed_permissions_via_open3
          require "open3"

          _stdin, stdout, stderr, wait_thr = open3_seed_permissions_process
          stderr_thread = stream_seed_permissions_stderr(stderr)
          stdout_thread = stream_seed_permissions_stdout(stdout)

          success = wait_thr.value.success?
          stderr_thread.join
          stdout_thread.join
          close_seed_permissions_streams(stdout, stderr)
          success
        end

        def open3_seed_permissions_process
          Open3.popen3(*seed_permissions_command, chdir: Rails.root.to_s)
        end

        def seed_permissions_command
          # Use argv form to avoid invoking a shell.
          %w[bin/rails ruby_cms:seed_permissions ruby_cms:import_initializer_settings]
        end

        def stream_seed_permissions_stderr(stderr)
          Thread.new do
            stderr.each_line do |line|
              $stderr.print line unless line.include?("already initialized constant")
            end
          end
        end

        def stream_seed_permissions_stdout(stdout)
          Thread.new do
            stdout.each_line {|line| $stdout.print line }
          end
        end

        def close_seed_permissions_streams(stdout, stderr)
          stdout.close
          stderr.close
        end

        def say_seed_permissions_outcome(success)
          if success
            say "✓ Task permissions: Seeded RubyCMS permissions", :green
          else
            say "⚠ Task permissions: Could not seed. " \
                "Run 'rails ruby_cms:seed_permissions' manually.",
                :yellow
          end
        end

        def say_seed_permissions_error(error)
          say "⚠ Task permissions: Could not seed: #{error.message}. " \
              "Run 'rails ruby_cms:seed_permissions' manually.",
              :yellow
        end

        def skip_setup_admin_due_to_existing_admin?
          return false unless user_with_admin_permissions_exists?

          say "ℹ Task setup_admin: User with admin permissions already exists. " \
              "Skipping setup_admin.",
              :cyan
          true
        end

        def setup_admin_tty?
          return true if $stdin.tty?

          say "ℹ Task setup_admin: Skipping interactive setup (non-TTY). " \
              "Run: rails ruby_cms:setup_admin",
              :yellow
          false
        end

        def run_setup_admin_task
          say "ℹ Task setup_admin: Running setup_admin (create or pick first admin).", :cyan
          run "bin/rails ruby_cms:setup_admin"
          say "✓ Task setup_admin: Completed", :green
        end

        def say_setup_admin_error(error)
          say "⚠ Task setup_admin: Failed or skipped: #{error.message}. " \
              "Run: rails ruby_cms:setup_admin",
              :yellow
        end

        def user_with_admin_permissions_exists? # rubocop:disable Metrics/MethodLength
          return false unless defined?(::User)

          begin
            # Ensure permissions exist first
            RubyCms::Permission.ensure_defaults!

            # Check if any user has ALL required admin permissions
            required_keys = %w[
              manage_admin
              manage_permissions
              manage_content_blocks
              manage_visitor_errors
              manage_analytics
            ]
            required_permission_ids = RubyCms::Permission.where(key: required_keys).pluck(:id)
            return false if required_permission_ids.size != required_keys.size

            # Find users who have all required permissions
            user_ids_with_all_perms = RubyCms::UserPermission
                                      .where(permission_id: required_permission_ids)
                                      .group(:user_id)
                                      .having("COUNT(DISTINCT permission_id) = ?", required_keys.size)
                                      .pluck(:user_id)

            user_ids_with_all_perms.any?
          rescue StandardError
            # If there's an error (e.g., tables don't exist yet), assume no admin exists
            false
          end
        end
      end

      def show_next_steps
        say NEXT_STEPS_MESSAGE, :green
      end
    end
  end
end
