# frozen_string_literal: true

require "fileutils"

module RubyCms
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def run_authentication
        user_path = Rails.root.join("app/models/user.rb")
        return if File.exist?(user_path)

        say "User model not found. Running 'rails g authentication' (Rails 8+).", :green
        @authentication_attempted = true
        run "bin/rails generate authentication"
        run "bundle install"
      rescue StandardError => e
        say "Could not run 'rails g authentication': #{e.message}.", :yellow
        say "On Rails 8+, run 'rails g authentication' and 'bundle install' manually. On Rails 7, add User, Session, and an Authentication concern yourself.",
            :yellow
      end

      def verify_auth
        unless defined?(::User)
          if @authentication_attempted
            say "Warning: User model not found. Run 'rails db:migrate' if the authentication generator succeeded, or run 'rails g authentication' manually (Rails 8+).",
                :yellow
          else
            say "Warning: User model not found. Run 'rails g authentication' (or ensure User exists) before using the admin.",
                :yellow
          end
        end
        unless defined?(::Session)
          say "Warning: Session model not found. The host app should provide authentication.", :yellow
        end
        ac_path = Rails.root.join("app/controllers/application_controller.rb")
        return unless ac_path.exist? && !File.read(ac_path).include?("Authentication")

        say "Note: ApplicationController does not appear to include an Authentication concern. Ensure /admin is protected.",
            :yellow
      end

      def create_initializer
        template "ruby_cms.rb", "config/initializers/ruby_cms.rb"
      end

      def mount_engine
        route 'mount RubyCms::Engine => "/"'
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

        content = File.read(auth_path)
        return if content.include?("def current_user")

        gsub_file auth_path, "    helper_method :authenticated?\n", "    helper_method :authenticated?, :current_user\n"
        inject_into_file auth_path, after: "  private\n" do
          "    def current_user\n      Current.user\n    end\n\n"
        end
      end

      def copy_fallback_css
        dest_dir = Rails.root.join("app/assets/stylesheets/ruby_cms")
        dest = dest_dir.join("admin.css")
        src = RubyCms::Engine.root.join("app/assets/stylesheets/ruby_cms/admin.css")
        return unless src.exist?

        FileUtils.mkdir_p(dest_dir)
        FileUtils.cp(src, dest, preserve: true) if !dest.exist? || File.mtime(src) > File.mtime(dest)
        say "Copied ruby_cms/admin.css (fallback for /admin when Tailwind is not loaded).", :green
      rescue StandardError => e
        say "Could not copy ruby_cms/admin.css: #{e.message}.", :yellow
      end

      def install_action_text
        migrate_dir = Rails.root.join("db/migrate")
        return unless migrate_dir.directory?

        existing = Dir.glob(migrate_dir.join("*.rb").to_s).join("\n")
        if existing.include?("create_action_text_rich_texts") || existing.include?("create_active_storage_tables")
          return
        end

        say "Installing Action Text (and Active Storage) for rich text/image content blocks.", :green
        run "bin/rails action_text:install"
      rescue StandardError => e
        say "Could not run action_text:install: #{e.message}. Rich text will be disabled until you install Action Text.",
            :yellow
      end

      def install_tailwind
        gemfile = Rails.root.join("Gemfile")
        tailwind_css = Rails.root.join("app/assets/tailwind/application.css")

        unless File.exist?(tailwind_css)
          if File.read(gemfile).include?("tailwindcss-rails")
            say "Tailwind CSS gem found; running tailwindcss:install.", :green
          else
            say "Adding tailwindcss-rails for admin styling (gvexcelsior-like).", :green
            run "bundle add tailwindcss-rails"
          end
          run "bin/rails tailwindcss:install"
        end

        add_ruby_cms_tailwind_source(tailwind_css)
        run "bin/rails tailwindcss:build" if File.exist?(tailwind_css)
        # Importmap pins are provided by the engine via `ruby_cms/config/importmap.rb`.
      rescue StandardError => e
        say "Could not install Tailwind: #{e.message}. Add tailwindcss-rails and run rails tailwindcss:install manually for styled /admin.",
            :yellow
      end

      def install_ruby_ui
        gemfile = Rails.root.join("Gemfile")
        gemfile_content = File.read(gemfile)
        return if gemfile_content.include?("ruby_ui") || gemfile_content.include?("rails_ui")

        say "Adding ruby_ui to Gemfile.", :green
        run "bundle add ruby_ui --group development --require false"
        run "bundle install"
      rescue StandardError => e
        say "Could not add ruby_ui: #{e.message}. Run 'bundle add ruby_ui --group development --require false' manually.",
            :yellow
        return
      end

      def run_ruby_ui_install
        gemfile = Rails.root.join("Gemfile")
        gemfile_content = File.read(gemfile)
        return unless gemfile_content.include?("ruby_ui") || gemfile_content.include?("rails_ui")

        # Check if ruby_ui is already installed
        ruby_ui_initializer = Rails.root.join("config/initializers/ruby_ui.rb")
        ruby_ui_base = Rails.root.join("app/components/ruby_ui/base.rb")
        if File.exist?(ruby_ui_initializer) || File.exist?(ruby_ui_base)
          say "ruby_ui is already installed. Skipping.", :green
          return
        end

        say "Running ruby_ui:install generator.", :green
        # Try ruby_ui:install first, fallback to rails_ui:install
        begin
          run "bin/rails generate ruby_ui:install"
        rescue StandardError
          begin
            say "Using rails_ui:install (ruby_ui alias).", :green
            run "bin/rails generate rails_ui:install"
          rescue StandardError => e
            say "Could not find ruby_ui:install or rails_ui:install generator: #{e.message}. Run 'rails g ruby_ui:install' manually.",
                :yellow
          end
        end
      end

      def add_ruby_ui_to_application_helper
        helper_path = Rails.root.join("app/helpers/application_helper.rb")
        return unless File.exist?(helper_path)

        content = File.read(helper_path)
        return if content.include?("include RubyUI") || content.include?("include RubyUi")

        say "Adding include RubyUI to ApplicationHelper.", :green
        inject_into_file helper_path.to_s, after: /module ApplicationHelper\n/ do
          "  include RubyUI\n"
        end
      rescue StandardError => e
        say "Could not add RubyUI to ApplicationHelper: #{e.message}. Add 'include RubyUI' manually.",
            :yellow
      end

      def generate_ruby_ui_components
        gemfile = Rails.root.join("Gemfile")
        gemfile_content = File.read(gemfile)
        return unless gemfile_content.include?("ruby_ui") || gemfile_content.include?("rails_ui")

        # Check if ruby_ui is installed
        ruby_ui_initializer = Rails.root.join("config/initializers/ruby_ui.rb")
        ruby_ui_base = Rails.root.join("app/components/ruby_ui/base.rb")
        unless File.exist?(ruby_ui_initializer) || File.exist?(ruby_ui_base)
          say "ruby_ui is not installed. Skipping component generation.", :yellow
          return
        end

        # Common components to generate
        components = %w[Card Button Text Heading Input Textarea Select Form Tooltip]

        say "Generating ruby_ui components.", :green
        components.each do |component|
          # Check if component already exists
          component_path = Rails.root.join("app/components/ruby_ui/#{component.underscore}")
          if Dir.exist?(component_path) || File.exist?(Rails.root.join("app/components/ruby_ui/#{component.underscore}.rb"))
            say "Component #{component} already exists. Skipping.", :green
            next
          end

          begin
            # Try ruby_ui:component first, fallback to rails_ui:component
            run "bin/rails generate ruby_ui:component #{component}"
          rescue StandardError
            begin
              run "bin/rails generate rails_ui:component #{component}"
            rescue StandardError => e
              say "Could not generate #{component}: #{e.message}.", :yellow
            end
          end
        end
      rescue StandardError => e
        say "Could not generate ruby_ui components: #{e.message}. Run 'rails g ruby_ui:component <ComponentName>' manually.",
            :yellow
      end

      # NOTE: Rails generators are Thor groups; private methods can still be
      # treated as "tasks" unless wrapped in `no_tasks`.
      no_tasks do
        def add_importmap_pins
          importmap_path = Rails.root.join("config/importmap.rb")
          return unless File.exist?(importmap_path)

          content = File.read(importmap_path)
          gem_js_path = RubyCms::Engine.root.join("app/javascript").relative_path_from(Rails.root).to_s
          return if content.include?("RubyCMS Stimulus controllers") ||
                    content.include?(%(pin_all_from "#{gem_js_path}/controllers", under: "controllers"))

          inject_into_file importmap_path.to_s, before: /^end/ do
            "\n  # RubyCMS Stimulus controllers\n  pin_all_from \"#{gem_js_path}/controllers\", under: \"controllers\"\n"
          end
          say "Added RubyCMS controllers to importmap.rb.", :green
        rescue StandardError => e
          say "Could not add importmap pins: #{e.message}. Ensure config/importmap.rb includes: pin_all_from \"<gem-path>/app/javascript/controllers\", under: \"controllers\"",
              :yellow
        end

        # Helper: add @source for RubyCMS views. Not a generator task.
        def add_ruby_cms_tailwind_source(tailwind_css_path)
          return unless tailwind_css_path.to_s.present? && File.exist?(tailwind_css_path)

          content = File.read(tailwind_css_path)
          gem_views = RubyCms::Engine.root.join("app/views").relative_path_from(Rails.root).to_s
          gem_source_line = %(@source "#{gem_views}/**/*.erb";)
          return if content.include?(gem_source_line)

          to_inject = +"\n/* Include RubyCMS admin views so Tailwind finds utility classes. */\n"
          to_inject << gem_source_line
          to_inject << "\n"

          # Try common insertion points; if none match, prepend.
          inserted = false
          [
            %(@import "tailwindcss";\n),
            %(@import "tailwindcss";),
            %(@import "tailwindcss"\n),
            %(@import "tailwindcss")
          ].each do |after_pattern|
            next unless content.include?(after_pattern)

            inject_into_file tailwind_css_path.to_s, after: after_pattern do
              to_inject
            end
            inserted = true
            break
          end
          unless inserted
            inject_into_file tailwind_css_path.to_s, after: /\A/ do
              to_inject
            end
          end
          say "Added @source for RubyCMS views to tailwind/application.css.", :green
        rescue StandardError => e
          say "Could not add @source for RubyCMS: #{e.message}. Add manually: @source \"<path-to-gem>/app/views/**/*.erb\";",
              :yellow
        end
      end

      def run_migrate
        say "Running db:migrate.", :green
        run "bin/rails db:migrate"
      rescue StandardError => e
        say "db:migrate failed: #{e.message}. Run rails db:create db:migrate if needed.", :yellow
      end

      def run_seed_permissions
        say "Seeding RubyCMS permissions.", :green
        run "bin/rails ruby_cms:seed_permissions"
      end

      def run_setup_admin
        # Check if a user with admin permissions already exists
        if user_with_admin_permissions_exists?
          say "User with admin permissions already exists. Skipping setup_admin.", :green
          return
        end

        unless $stdin.tty?
          say "Skipping interactive setup_admin (non-TTY). Run: rails ruby_cms:setup_admin", :yellow
          return
        end
        say "Running setup_admin (create or pick first admin).", :green
        run "bin/rails ruby_cms:setup_admin"
      rescue StandardError => e
        say "setup_admin failed or skipped: #{e.message}. Run: rails ruby_cms:setup_admin", :yellow
      end

      no_tasks do
        def user_with_admin_permissions_exists?
          return false unless defined?(::User)

          begin
            # Ensure permissions exist first
            RubyCms::Permission.ensure_defaults!

            # Check if any user has the manage_admin permission
            manage_admin_perm = RubyCms::Permission.find_by(key: "manage_admin")
            return false unless manage_admin_perm

            # Check if any UserPermission exists for manage_admin
            RubyCms::UserPermission.where(permission: manage_admin_perm).exists?
          rescue StandardError
            # If there's an error (e.g., tables don't exist yet), assume no admin exists
            false
          end
        end
      end

      def show_next_steps
        say <<~TEXT, :green

          RubyCMS install complete.

          Next (if not already done by install):
          - rails db:migrate
          - rails ruby_cms:seed_permissions
          - rails ruby_cms:setup_admin   (or: rails ruby_cms:grant_manage_admin email=you@example.com)

          Notes:
          - If the host uses /admin already, remove or change those routes.
          - Avoid root to: redirect("/admin") — use a real root or ruby_cms.unauthorized_redirect_path.
          - Review config/initializers/ruby_cms.rb (session, CSP).
          - Add 'css: bin/rails tailwindcss:watch' to Procfile.dev for Tailwind in development.
          - Visit /admin (sign in as the admin you configured).
        TEXT
      end
    end
  end
end
