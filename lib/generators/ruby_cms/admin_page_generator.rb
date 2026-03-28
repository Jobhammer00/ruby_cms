# frozen_string_literal: true

module RubyCms
  module Generators
    class AdminPageGenerator < ::Rails::Generators::NamedBase
      source_root File.expand_path("templates/admin_page", __dir__)

      class_option :permission, type: :string, default: nil,
                                desc: "Permission key (default: manage_<name>)"
      class_option :icon, type: :string, default: "folder",
                          desc: "Named icon from RubyCms::Icons (e.g. archive_box, bell, clock). " \
                                "Run RubyCms::Icons.available for the full list."
      class_option :section, type: :string, default: "main",
                             desc: "Navigation section: main or settings"
      class_option :order, type: :numeric, default: 10,
                           desc: "Sort order within the nav section"

      def validate_options
        raise ArgumentError, "--section must be 'main' or 'settings', got '#{section_name}'" unless %w[main settings].include?(section_name)

        icon_sym = icon_name.to_sym
        return if RubyCms::Icons::REGISTRY.key?(icon_sym)

        say "Warning: icon '#{icon_name}' is not in RubyCms::Icons::REGISTRY. " \
            "Available: #{RubyCms::Icons.available.join(', ')}", :yellow
      end

      def create_controller
        template "controller.rb.tt",
                 File.join("app/controllers/admin", "#{file_name}_controller.rb")
      end

      def create_view
        template "index.html.erb.tt",
                 File.join("app/views/admin", file_name, "index.html.erb")
      end

      def add_route
        routes_path = Rails.root.join("config/routes.rb")
        return unless routes_path.exist?

        content = File.read(routes_path)
        route_line = "    resources :#{plural_name}, only: [:index], controller: \"admin/#{file_name}\""

        if content.include?("resources :#{plural_name}") && content.include?("admin/#{file_name}")
          say "Route already exists, skipping.", :yellow
          return
        end

        if content.match?(/namespace\s+:admin\s+do/)
          inject_into_file routes_path.to_s, after: /namespace\s+:admin\s+do\s*\n/ do
            "#{route_line}\n"
          end
        else
          route <<~RUBY
            namespace :admin do
            #{route_line}
            end
          RUBY
        end
        say "Route: added admin/#{plural_name}", :green
      end

      def add_page_registration
        pages_file = Rails.root.join("config/initializers/ruby_cms_pages.rb")

        registration = register_page_code

        if pages_file.exist?
          content = File.read(pages_file)
          if content.include?("key: :#{file_name}")
            say "Page registration already exists, skipping.", :yellow
            return
          end
          append_to_file pages_file.to_s, "\n#{registration}\n"
        else
          create_file pages_file.to_s, "# frozen_string_literal: true\n\n#{registration}\n"
        end
        say "Registered page :#{file_name} in config/initializers/ruby_cms_pages.rb", :green
      end

      def show_next_steps
        say "\nAdmin page '#{file_name}' created.", :green
        say "Next: rails ruby_cms:seed_permissions", :cyan
      end

      private

      def permission_key
        options[:permission].presence || "manage_#{file_name}"
      end

      def icon_name
        options[:icon]
      end

      def section_name
        options[:section]
      end

      def order_value
        options[:order]
      end

      def path_helper_name
        "admin_#{plural_name}_path"
      end

      def register_page_code
        <<~RUBY
          Rails.application.config.to_prepare do
            RubyCms.register_page(
              key: :#{file_name},
              label: "#{human_name}",
              path: :#{path_helper_name},
              icon: :#{icon_name},
              section: :#{section_name},
              permission: :#{permission_key},
              order: #{order_value}
            )
          end
        RUBY
      end
    end
  end
end
