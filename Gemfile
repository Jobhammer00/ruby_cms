# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in ruby_cms.gemspec
gemspec

gem "nokogiri", ">= 1.19.1"
gem "rack", ">= 3.2.5"

gem "irb"
gem "rake", "~> 13.0"

gem "factory_bot_rails"
gem "rspec", "~> 3.0"
gem "rspec-rails", "~> 6.0"
gem "shoulda-matchers"
gem "sqlite3"

group :development, :test, :ci, :linter do
  gem 'bundler-audit', require: false
  gem 'erb_lint', require: false
  gem 'rubocop', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-rspec', require: false
  gem 'rubocop-rspec_rails', require: false
end

group :linter, optional: true do
  gem 'pronto'
  gem 'pronto-annotations_formatter'
  gem 'pronto-erb_lint'
  gem 'pronto-rubocop'
  gem 'pronto-yamllint'
end
