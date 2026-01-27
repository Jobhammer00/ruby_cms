# frozen_string_literal: true

require_relative "lib/ruby_cms/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_cms"
  spec.version = RubyCms::VERSION
  spec.authors = ["Job Hammer"]
  spec.email = ["job.hammer@moneybird.com"]

  spec.summary = "Complete CMS engine for Rails with visual editor and content management"
  spec.description = <<~DESC
    RubyCMS is a Rails engine that provides a CMS solution for managing content
    while developers focus on SaaS product features. It includes:

    - Visual editor with inline editing
    - Content blocks with rich text support
    - Permission-based access control
    - User management
    - Page display (pages created programmatically)
  DESC
  spec.homepage = "https://github.com/jobhammer/ruby_cms"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/jobhammer/ruby_cms"
  spec.metadata["changelog_uri"] = "https://github.com/jobhammer/ruby_cms/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) {|f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "actiontext", ">= 7.1"
  spec.add_dependency "rails", ">= 7.1"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
