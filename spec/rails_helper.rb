# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

require_relative "spec_helper"
require "rails"
require "rails/engine"
require "active_record/railtie"
require "action_controller/railtie"
require "ruby_cms"           # <-- move up

module RubyCmsSpec
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = "ruby_cms_spec_secret_key_base"
    config.hosts << "www.example.com" if config.respond_to?(:hosts)
  end
end

RubyCmsSpec::Application.initialize!
require "rspec/rails"

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
