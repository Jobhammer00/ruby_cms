# frozen_string_literal: true

namespace :ruby_cms do
  namespace :css do
    desc "Compile RubyCMS admin.css from component files (for gem development)"
    task compile_gem: :environment do
      require "ruby_cms/engine" unless defined?(RubyCms::Engine)

      dest = RubyCms::Engine.root.join("app/assets/stylesheets/ruby_cms/admin.css")
      RubyCms::Engine.compile_admin_css(dest)
      puts "✓ Compiled admin.css in gem"
    end

    desc "Compile RubyCMS CSS to host app (combines component files)"
    task compile: :environment do
      require "fileutils"
      require "ruby_cms/engine" unless defined?(RubyCms::Engine)

      dest_dir = Rails.root.join("app/assets/stylesheets/ruby_cms")
      FileUtils.mkdir_p(dest_dir)
      dest = dest_dir.join("admin.css")
      RubyCms::Engine.compile_admin_css(dest)
      puts "✓ Compiled admin.css to #{dest}"
      puts "✓ RubyCMS CSS compilation complete!"
    end
  end
end
