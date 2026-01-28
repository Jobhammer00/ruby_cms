# frozen_string_literal: true

namespace :ruby_cms do
  namespace :css do
    desc "Compile RubyCMS CSS files (resolves @import statements)"
    task compile: :environment do
      require "pathname"
      require "fileutils"

      src_dir = RubyCms::Engine.root.join("app/assets/stylesheets/ruby_cms")
      dest_dir = Rails.root.join("app/assets/stylesheets/ruby_cms")

      unless src_dir.exist?
        puts "Error: Source directory not found: #{src_dir}"
        exit 1
      end

      FileUtils.mkdir_p(dest_dir)

      # Read admin.css
      admin_css_src = src_dir.join("admin.css")
      unless admin_css_src.exist?
        puts "Error: admin.css not found: #{admin_css_src}"
        exit 1
      end

      admin_css_content = File.read(admin_css_src)

      # Resolve @import statements
      components_dir = src_dir.join("components")
      if components_dir.exist? && components_dir.directory?
        admin_css_content = admin_css_content.gsub(%r{@import\s+["'](?:ruby_cms/)?components/([^"']+)\.css["'];?}) do |match|
          component_name = Regexp.last_match(1)
          component_file = components_dir.join("#{component_name}.css")
          if component_file.exist?
            "\n/* ===== Component: #{component_name} ===== */\n" + File.read(component_file) + "\n"
          else
            puts "Warning: Component file not found: #{component_file}"
            match
          end
        end
      end

      # Write compiled CSS
      admin_css_dest = dest_dir.join("admin.css")
      File.write(admin_css_dest, admin_css_content)
      puts "✓ Compiled admin.css to #{admin_css_dest}"

      # Don't copy component files - only the compiled admin.css is needed
      # Component files are only in the gem for development/organization

      puts "✓ RubyCMS CSS compilation complete!"
    end
  end
end
