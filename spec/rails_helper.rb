# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "spec_helper"
require "rails"
require "rails/engine"
require "active_record/railtie"
require "action_controller/railtie"
require "ruby_cms" # <-- move up

require_relative "support/dummy_app"
require_relative "support/application_record"
require "rspec/rails"
