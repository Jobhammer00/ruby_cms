# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

# CSS compile (no Rails needed - for gem development)
namespace :ruby_cms do
  namespace :css do
    desc "Compile RubyCMS admin.css from component files (for gem development)"
    task compile_gem: :environment do
      require_relative "lib/ruby_cms/css_compiler"
      gem_root = __dir__
      dest = File.join(gem_root, "app/assets/stylesheets/ruby_cms/admin.css")
      RubyCms::CssCompiler.compile(gem_root, dest)
      puts "✓ Compiled admin.css in gem"
    end
  end
end

task :environment do
  # No-op for gem Rakefile; Rails app Rakefiles load full env
end

task default: %i[spec rubocop]
