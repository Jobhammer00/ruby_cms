# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "spec_helper"

# Boot a minimal dummy Rails app for engine specs.
require_relative "dummy/config/environment"

require "rspec/rails"

# Load support files
Dir[File.expand_path("support/**/*.rb", __dir__)].sort.each {|f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  # Infer spec type from file location (models/controllers/helpers/jobs)
  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!
end
