# frozen_string_literal: true

require "fileutils"

module RubyCms
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      def run_authentication
        user_path = Rails.root.join("app/models/user.rb")
        return if File.exist?(user_path)

        say "ℹ Task authentication: User model not found. Running 'rails g authentication' (Rails 8+).",
            :cyan
        @authentication_attempted = true
        run "bin/rails generate authentication"
        run "bundle install"
      rescue StandardError => e
        say "⚠ Could not run 'rails g authentication': #{e.message}.", :yellow
        say "   On Rails 8+, run 'rails g authentication' and 'bundle install' manually.", :yellow
      end

      def verify_auth
        unless defined?(::User)
          if @authentication_attempted
            say "ℹ Task authentication: Run 'rails db:migrate' if the authentication generator succeeded.",
                :yellow
          else
            say "ℹ Task authentication: User model not found. Run 'rails g authentication' before using /admin.",
                :yellow
          end
        end
        unless defined?(::Session)
          say "ℹ Task authentication: Session model not found. The host app should provide authentication.",
              :yellow
        end
        ac_path = Rails.root.join("app/controllers/application_controller.rb")
        return unless ac_path.exist? && !File.read(ac_path).include?("Authentication")

        say "ℹ Task authentication: ApplicationController does not include Authentication. Ensure /admin is protected.",
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

        gsub_file auth_path, "    helper_method :authenticated?\n",
                  "    helper_method :authenticated?, :current_user\n"
        inject_into_file auth_path, after: "  private\n" do
          "    def current_user\n      Current.user\n    end\n\n"
        end
      end

      def copy_fallback_css
        src_dir = RubyCms::Engine.root.join("app/assets/stylesheets/ruby_cms")
        dest_dir = Rails.root.join("app/assets/stylesheets/ruby_cms")

        return unless src_dir.exist?

        FileUtils.mkdir_p(dest_dir)

        # Copy main admin.css file
        admin_css_src = src_dir.join("admin.css")
        admin_css_dest = dest_dir.join("admin.css")
        if admin_css_src.exist? && (!admin_css_dest.exist? || File.mtime(admin_css_src) > File.mtime(admin_css_dest))
          FileUtils.cp(admin_css_src, admin_css_dest, preserve: true)
        end

        # Copy components directory if it exists
        components_src_dir = src_dir.join("components")
        components_dest_dir = dest_dir.join("components")

        if components_src_dir.exist? && components_src_dir.directory?
          FileUtils.mkdir_p(components_dest_dir)

          # Copy all CSS files from components directory
          Dir.glob(components_src_dir.join("*.css")).each do |src_file|
            filename = File.basename(src_file)
            dest_file = components_dest_dir.join(filename)
            if !dest_file.exist? || File.mtime(src_file) > File.mtime(dest_file)
              FileUtils.cp(src_file, dest_file,
                           preserve: true)
            end
          end
        end

        say "✓ Task css/copy: Copied RubyCMS CSS files to app/assets/stylesheets/ruby_cms/.", :green
      rescue StandardError => e
        say "⚠ Task css/copy: Could not copy CSS files: #{e.message}.", :yellow
      end

      def install_action_text
        migrate_dir = Rails.root.join("db/migrate")
        return unless migrate_dir.directory?

        existing = Dir.glob(migrate_dir.join("*.rb").to_s).join("\n")
        if existing.include?("create_action_text_rich_texts") || existing.include?("create_active_storage_tables")
          return
        end

        say "ℹ Task action_text: Installing Action Text for rich text/image content blocks.", :cyan
        run "bin/rails action_text:install"
        say "✓ Task action_text: Installed Action Text", :green
      rescue StandardError => e
        say "⚠ Task action_text: Could not install: #{e.message}. Rich text will be disabled.",
            :yellow
      end

      def install_tailwind
        gemfile = Rails.root.join("Gemfile")
        tailwind_css = Rails.root.join("app/assets/tailwind/application.css")

        unless File.exist?(tailwind_css)
          if File.read(gemfile).include?("tailwindcss-rails")
            say "ℹ Task tailwind: Tailwind CSS gem found; running tailwindcss:install.", :cyan
          else
            say "ℹ Task tailwind: Adding tailwindcss-rails for admin styling.", :cyan
            run "bundle add tailwindcss-rails"
          end
          run "bin/rails tailwindcss:install"
          say "✓ Task tailwind: Installed Tailwind CSS", :green
        end

        add_ruby_cms_tailwind_source(tailwind_css)
        run "bin/rails tailwindcss:build" if File.exist?(tailwind_css)
        # Importmap pins are provided by the engine via `ruby_cms/config/importmap.rb`.
        add_importmap_pins
        add_stimulus_registration
      rescue StandardError => e
        say "⚠ Task tailwind: Could not install: #{e.message}. Add tailwindcss-rails manually.",
            :yellow
      end

      def install_ruby_ui
        gemfile = Rails.root.join("Gemfile")
        gemfile_content = File.read(gemfile)
        return if gemfile_content.include?("ruby_ui") || gemfile_content.include?("rails_ui")

        say "ℹ Task ruby_ui: Adding ruby_ui to Gemfile.", :cyan
        run "bundle add ruby_ui --group development --require false"
        run "bundle install"
        say "✓ Task ruby_ui: Added ruby_ui to Gemfile", :green
      rescue StandardError => e
        say "⚠ Task ruby_ui: Could not add: #{e.message}. Run 'bundle add ruby_ui --group development --require false' manually.",
            :yellow
        nil
      end

      def run_ruby_ui_install
        gemfile = Rails.root.join("Gemfile")
        gemfile_content = File.read(gemfile)
        return unless gemfile_content.include?("ruby_ui") || gemfile_content.include?("rails_ui")

        # Check if ruby_ui is already installed
        ruby_ui_initializer = Rails.root.join("config/initializers/ruby_ui.rb")
        ruby_ui_base = Rails.root.join("app/components/ruby_ui/base.rb")
        if File.exist?(ruby_ui_initializer) || File.exist?(ruby_ui_base)
          say "ℹ Task ruby_ui:install: ruby_ui is already installed. Skipping.", :cyan
          return
        end

        say "ℹ Task ruby_ui:install: Running ruby_ui:install generator.", :cyan
        # Try ruby_ui:install first, fallback to rails_ui:install
        begin
          run "bin/rails generate ruby_ui:install"
          say "✓ Task ruby_ui:install: Installed ruby_ui", :green
        rescue StandardError
          begin
            say "ℹ Task ruby_ui:install: Using rails_ui:install (ruby_ui alias).", :cyan
            run "bin/rails generate rails_ui:install"
            say "✓ Task ruby_ui:install: Installed rails_ui", :green
          rescue StandardError => e
            say "⚠ Task ruby_ui:install: Could not find generator: #{e.message}. Run 'rails g ruby_ui:install' manually.",
                :yellow
          end
        end
      end

      def add_ruby_ui_to_application_helper
        helper_path = Rails.root.join("app/helpers/application_helper.rb")
        return unless File.exist?(helper_path)

        content = File.read(helper_path)
        return if content.include?("include RubyUI") || content.include?("include RubyUi")

        say "✓ Task ruby_ui/helper: Added include RubyUI to ApplicationHelper.", :green
        inject_into_file helper_path.to_s, after: /module ApplicationHelper\n/ do
          "  include RubyUI\n"
        end
      rescue StandardError => e
        say "⚠ Task ruby_ui/helper: Could not add RubyUI: #{e.message}. Add 'include RubyUI' manually.",
            :yellow
      end

      def generate_ruby_ui_components
        # Skip component generation - components were mainly for page builder which has been removed
        # Users can generate components manually if needed: rails g ruby_ui:component ComponentName
        say "ℹ Task ruby_ui/components: Skipping automatic component generation (page builder removed). Generate components manually if needed: rails g ruby_ui:component ComponentName",
            :cyan
      end

      # NOTE: Rails generators are Thor groups; private methods can still be
      # treated as "tasks" unless wrapped in `no_tasks`.
      no_tasks do # rubocop:disable Metrics/BlockLength
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
          say "✓ Task importmap: Added RubyCMS controllers to importmap.rb.", :green
        rescue StandardError => e
          say "⚠ Task importmap: Could not add pins: #{e.message}. Add manually to config/importmap.rb.",
              :yellow
        end

        def add_stimulus_registration
          # Ensure Stimulus application is exposed on window for auto-registration
          controllers_app_path = Rails.root.join("app/javascript/controllers/application.js")

          if File.exist?(controllers_app_path)
            content = File.read(controllers_app_path)

            # Check if window.Stimulus or window.application is already set
            if content.include?("window.Stimulus") || content.include?("window.application")
              say "ℹ Task stimulus: Stimulus application is already exposed on window.", :cyan
            elsif content.include?("Application.start") || content.include?("const application")
              # Try to add window.Stimulus = application after application is created
              # Match patterns like:
              #   const application = Application.start()
              #   application = Application.start()
              if content.match?(/const\s+application\s*=\s*Application\.start\(\)/)
                gsub_file controllers_app_path.to_s,
                          /const\s+application\s*=\s*Application\.start\(\)/,
                          "const application = Application.start()\nwindow.Stimulus = application"
                say "✓ Task stimulus: Added window.Stimulus = application to controllers/application.js.",
                    :green
              elsif content.match?(/application\s*=\s*Application\.start\(\)/)
                gsub_file controllers_app_path.to_s,
                          /application\s*=\s*Application\.start\(\)/,
                          "application = Application.start()\nwindow.Stimulus = application"
                say "✓ Task stimulus: Added window.Stimulus = application to controllers/application.js.",
                    :green
              else
                say "⚠ Task stimulus: Could not automatically expose. Manually add 'window.Stimulus = application'.",
                    :yellow
              end
            else
              say "⚠ Task stimulus: Could not find Stimulus application setup. Ensure app/javascript/controllers/application.js exists.",
                  :yellow
            end
          else
            say "⚠ Task stimulus: Could not find app/javascript/controllers/application.js. RubyCMS controllers may need manual setup.",
                :yellow
          end

          # No explicit registration needed - auto-registration in ruby_cms/index.js handles it
          # Clean up any old manual registration code that might cause errors
          cleanup_old_registration_code
        end

        def cleanup_old_registration_code
          # Check application.js for old manual registration code
          js_files = [
            Rails.root.join("app/javascript/application.js"),
            Rails.root.join("app/javascript/index.js"),
            Rails.root.join("app/javascript/entrypoints/application.js")
          ].select(&:exist?)

          js_files.each do |js_file|
            content = File.read(js_file)
            # Check for problematic manual registration code
            unless content.include?("registerRubyCmsControllers(application)") && !content.include?("if (typeof application !== \"undefined\")")
              next
            end

            # Remove the problematic lines
            lines = content.split("\n")
            new_lines = lines.reject do |line|
              line.strip.include?("registerRubyCmsControllers(application)") ||
                (line.strip.start_with?("import") && line.include?("registerRubyCmsControllers") && line.include?("ruby_cms"))
            end

            next unless new_lines.length < lines.length

            File.write(js_file, new_lines.join("\n"))
            say "✓ Task stimulus: Removed old manual registration from #{js_file.basename}. Auto-registration handles this now.",
                :green
          end
        rescue StandardError
          # Silent fail - not critical
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
          say "✓ Task tailwind/source: Added @source for RubyCMS views to tailwind/application.css.",
              :green
        rescue StandardError => e
          say "⚠ Task tailwind/source: Could not add @source: #{e.message}. Add manually.", :yellow
        end
      end

      def run_migrate
        say "ℹ Task db:migrate: Running db:migrate.", :cyan
        run "bin/rails db:migrate"
        say "✓ Task db:migrate: Completed", :green
      rescue StandardError => e
        say "⚠ Task db:migrate: Failed: #{e.message}. Run rails db:create db:migrate if needed.",
            :yellow
      end

      def run_seed_permissions
        say "ℹ Task permissions: Seeding RubyCMS permissions.", :cyan
        # Suppress harmless RubyGems/Bundler warnings (Ruby 4.0.1 compatibility)
        # These warnings don't affect functionality
        require "open3"
        _stdin, stdout, stderr, wait_thr = Open3.popen3("bin/rails ruby_cms:seed_permissions",
                                                        chdir: Rails.root.to_s)

        # Filter stderr to exclude "already initialized constant" warnings
        Thread.new do
          stderr.each_line do |line|
            $stderr.print line unless line.include?("already initialized constant")
          end
        end

        # Pass through stdout
        Thread.new do
          stdout.each_line {|line| $stdout.print line }
        end

        success = wait_thr.value.success?
        stdout.close
        stderr.close

        if success
          say "✓ Task permissions: Seeded RubyCMS permissions", :green
        else
          say "⚠ Task permissions: Could not seed. Run 'rails ruby_cms:seed_permissions' manually.",
              :yellow
        end
      rescue StandardError => e
        say "⚠ Task permissions: Could not seed: #{e.message}. Run 'rails ruby_cms:seed_permissions' manually.",
            :yellow
      end

      def run_setup_admin
        # Check if a user with admin permissions already exists
        if user_with_admin_permissions_exists?
          say "ℹ Task setup_admin: User with admin permissions already exists. Skipping setup_admin.",
              :cyan
          return
        end

        unless $stdin.tty?
          say "ℹ Task setup_admin: Skipping interactive setup (non-TTY). Run: rails ruby_cms:setup_admin",
              :yellow
          return
        end
        say "ℹ Task setup_admin: Running setup_admin (create or pick first admin).", :cyan
        run "bin/rails ruby_cms:setup_admin"
        say "✓ Task setup_admin: Completed", :green
      rescue StandardError => e
        say "⚠ Task setup_admin: Failed or skipped: #{e.message}. Run: rails ruby_cms:setup_admin",
            :yellow
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

          ✓ RubyCMS install complete.

          Next steps (if not already done):
          - rails db:migrate
          - rails ruby_cms:seed_permissions
          - rails ruby_cms:setup_admin (or: rails ruby_cms:grant_manage_admin email=you@example.com)

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
