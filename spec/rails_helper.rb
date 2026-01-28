# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "spec_helper"

# Boot a minimal Rails app for engine specs (no dummy app needed).
require "rails"
require "rails/engine"
require "active_record/railtie"
require "action_controller/railtie"

module RubyCmsSpec
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = "ruby_cms_spec_secret_key_base"
    config.hosts << "www.example.com" if config.respond_to?(:hosts)
  end
end

RubyCmsSpec::Application.initialize!

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

require "rspec/rails"
require "ruby_cms"

# Load support files
Dir[File.expand_path("support/**/*.rb", __dir__)].each {|f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Infer spec type from file location (models/controllers/helpers/jobs)
  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!
end
