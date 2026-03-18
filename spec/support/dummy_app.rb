# frozen_string_literal: true

module RubyCmsSpec
  class Application < Rails::Application
    config.eager_load = false
    config.secret_key_base = "ruby_cms_spec_secret_key_base"
    config.hosts << "www.example.com" if config.respond_to?(:hosts)
  end
end

RubyCmsSpec::Application.initialize!
