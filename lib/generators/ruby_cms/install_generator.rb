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
        - rails ruby_cms:seed_permissions
        - rails ruby_cms:setup_admin (or: rails ruby_cms:grant_manage_admin email=you@example.com)
        - To seed content blocks from YAML: add content under content_blocks in config/locales/<locale>.yml, then run rails ruby_cms:content_blocks:seed (or call it from db/seeds.rb).

        Notes:
        - If the host uses /admin already, remove or change those routes.
        - Avoid root to: redirect("/admin") — use a real root or ruby_cms.unauthorized_redirect_path.
        - Review config/initializers/ruby_cms.rb (session, CSP).
        - Add 'css: bin/rails tailwindcss:watch' to Procfile.dev for Tailwind in development.
        - Visit /admin (sign in as the admin you configured).
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

      def copy_fallback_css
        src_dir = RubyCms::Engine.root.join("app/assets/stylesheets/ruby_cms")
        dest_dir = Rails.root.join("app/assets/stylesheets/ruby_cms")

        return unless src_dir.exist?

        FileUtils.mkdir_p(dest_dir)
        copy_admin_css(src_dir, dest_dir)
        # Don't copy component files - only the compiled admin.css is needed
        # copy_components_css(src_dir, dest_dir)
        notify_css_copy
      rescue StandardError => e
        say "⚠ Task css/copy: Could not copy CSS files: #{e.message}.", :yellow
      end

      def notify_css_copy
        say "✓ Task css/copy: Compiled and copied RubyCMS CSS to " \
            "app/assets/stylesheets/ruby_cms/admin.css", :green
        say "  (admin.css is compiled with all component styles inlined - no @import statements)",
            :green
      end

      no_tasks do # rubocop:disable Metrics/BlockLength
        def copy_admin_css(src_dir, dest_dir)
          admin_css_src = src_dir.join("admin.css")
          admin_css_dest = dest_dir.join("admin.css")
          return unless admin_css_src.exist?

          # Read the admin.css file
          admin_css_content = File.read(admin_css_src)

          # Find all @import statements and replace them with actual file contents
          components_dir = src_dir.join("components")
          if components_dir.exist? && components_dir.directory?
            admin_css_content = resolve_css_imports(admin_css_content, components_dir)
          end

          # Write the compiled CSS file (always write to ensure imports are resolved)
          # This creates a single compiled admin.css with all CSS inlined (no @import statements)
          File.write(admin_css_dest, admin_css_content)
        end

        def resolve_css_imports(css_content, components_dir)
          # Match @import "ruby_cms/components/X.css" or @import "components/X.css"
          pattern = %r{@import\s+["'](?:ruby_cms/)?components/([^"']+)\.css["'];?}
          css_content.gsub(pattern) {|m| resolve_css_import_match(m, components_dir) }
        end

        def resolve_css_import_match(match, components_dir)
          component_name = Regexp.last_match(1)
          component_file = components_dir.join("#{component_name}.css")
          if component_file.exist?
            "\n/* ===== Component: #{component_name} ===== */\n#{File.read(component_file)}\n"
          else
            say "⚠ Warning: Component file not found: #{component_file}", :yellow
            match
          end
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
        tailwind_css = Rails.root.join("app/assets/tailwind/application.css")

        install_tailwind_if_needed(gemfile, tailwind_css)
        configure_tailwind(tailwind_css)
      rescue StandardError => e
        say "⚠ Task tailwind: Could not install: #{e.message}. Add tailwindcss-rails manually.",
            :yellow
      end

      no_tasks do
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

      no_tasks do # rubocop:disable Metrics/BlockLength
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
      end

      # Directories to skip when scanning for page templates
      SKIP_PAGE_DIRS = %w[layouts shared mailers components admin].freeze

      # NOTE: Rails generators are Thor groups; private methods can still be
      # treated as "tasks" unless wrapped in `no_tasks`.
      no_tasks do # rubocop:disable Metrics/BlockLength
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
          scan_files_in_directory(dir_path, pages, relative_path)
          scan_subdirectories(dir_path, pages, views_base, relative_path)
        end

        private

        def scan_files_in_directory(dir_path, pages, relative_path)
          Dir.glob(File.join(dir_path, "*.{html.erb,html.haml,html.slim}")).each do |template_file|
            base_name = File.basename(template_file, ".*")
            base_name = File.basename(base_name, ".*") # remove .html extension

            next if skip_template?(base_name, relative_path)

            page_key, template_path = build_template_path(base_name, relative_path)
            pages[page_key] = template_path
          end
        end

        def skip_template?(base_name, relative_path)
          base_name.start_with?("_") || relative_path.start_with?("admin") ||
            relative_path == "admin"
        end

        def build_template_path(base_name, relative_path)
          if relative_path.empty?
            [base_name, base_name]
          elsif base_name == "index"
            [relative_path.split("/").last, "#{relative_path}/index"]
          else
            [base_name, "#{relative_path}/#{base_name}"]
          end
        end

        def scan_subdirectories(dir_path, pages, views_base, relative_path)
          Dir.glob(File.join(dir_path, "*")).each do |path|
            next unless File.directory?(path)

            dir_name = File.basename(path)
            next if skip_directory?(dir_name, relative_path)

            new_relative_path = relative_path.empty? ? dir_name : "#{relative_path}/#{dir_name}"
            scan_for_templates(path, pages, views_base, new_relative_path)
          end
        end

        def skip_directory?(dir_name, relative_path)
          InstallGenerator::SKIP_PAGE_DIRS.include?(dir_name) ||
            relative_path.start_with?("admin") || directory_too_deep?(relative_path)
        end

        def directory_too_deep?(relative_path)
          depth = relative_path.empty? ? 1 : relative_path.split("/").length + 1
          depth > 2
        end

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

        def import_rubycms_controllers(controllers_app_path, _content=nil)
          content = reload_content(controllers_app_path)
          return if already_imported?(content)

          return say_success if inject_after_first_import?(controllers_app_path, content)
          return say_success if inject_at_top(controllers_app_path)

          say_success if inject_after_stimulus_import?(controllers_app_path, content)
        rescue StandardError => e
          say_import_error(e)
        end

        def reload_content(path)
          File.read(path) if File.exist?(path)
        end

        def already_imported?(content)
          content.include?('import "ruby_cms"') || content.include?("import 'ruby_cms'") ||
            content.include?("registerRubyCmsControllers")
        end

        def inject_after_stimulus_import?(path, content)
          pattern = %r{import\s+.*@hotwired/stimulus.*$}
          return false unless content.match?(pattern)

          inject_into_file path.to_s, after: pattern, verbose: false do
            "\nimport \"ruby_cms\""
          end
          true
        end

        def inject_after_first_import?(path, content)
          pattern = /^import\s+.*$/m
          return false unless content.match?(pattern)

          inject_into_file path.to_s, after: pattern, verbose: false do
            "\nimport \"ruby_cms\""
          end
          true
        end

        def inject_at_top(path)
          prepend_to_file path.to_s, "import \"ruby_cms\"\n"
        end

        def say_success
          say "✓ Task stimulus: Added RubyCMS controllers import.", :green
        end

        def say_import_error(error)
          say "⚠ Task stimulus: Could not add RubyCMS import: #{error.message}. " \
              "Add 'import \"ruby_cms\"' manually to controllers/application.js.",
              :yellow
        end

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

        # Helper: add @source for RubyCMS views. Not a generator task.
        def add_ruby_cms_tailwind_source(tailwind_css_path)
          return unless tailwind_css_path.to_s.present? && File.exist?(tailwind_css_path)

          content = File.read(tailwind_css_path)
          gem_source_line = build_gem_source_line
          return if content.include?(gem_source_line)

          inject_tailwind_source(tailwind_css_path, content, gem_source_line)
        rescue StandardError => e
          say "⚠ Task tailwind/source: Could not add @source: #{e.message}. Add manually.", :yellow
        end

        def build_gem_source_line
          gem_views = RubyCms::Engine.root.join("app/views").relative_path_from(Rails.root).to_s
          %(@source "#{gem_views}/**/*.erb";)
        end

        def inject_tailwind_source(tailwind_css_path, content, gem_source_line)
          to_inject = build_tailwind_source_injection(gem_source_line)
          inserted = try_insert_after_patterns?(tailwind_css_path, content, to_inject)
          inject_at_start(tailwind_css_path, to_inject) unless inserted
          say "✓ Task tailwind/source: Added @source for RubyCMS views to " \
              "tailwind/application.css.",
              :green
        end

        def build_tailwind_source_injection(gem_source_line)
          to_inject = +"\n/* Include RubyCMS admin views so Tailwind finds utility classes. */\n"
          to_inject << gem_source_line
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
        run "bin/rails db:migrate"
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

      no_tasks do # rubocop:disable Metrics/BlockLength
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
          Open3.popen3(seed_permissions_command, chdir: Rails.root.to_s)
        end

        def seed_permissions_command
          "bin/rails ruby_cms:seed_permissions"
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

        def user_with_admin_permissions_exists?
          return false unless defined?(::User)

          begin
            # Ensure permissions exist first
            RubyCms::Permission.ensure_defaults!

            # Check if any user has the manage_admin permission
            manage_admin_perm = RubyCms::Permission.find_by(key: "manage_admin")
            return false unless manage_admin_perm

            # Check if any UserPermission exists for manage_admin
            RubyCms::UserPermission.exists?(permission: manage_admin_perm)
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
