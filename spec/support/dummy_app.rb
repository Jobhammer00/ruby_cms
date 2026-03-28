# frozen_string_literal: true

module RubyCmsSpec
  class Application < Rails::Application
    config.root = File.expand_path("../..", __dir__)
    config.eager_load = false
    config.secret_key_base = "ruby_cms_spec_secret_key_base"
    config.hosts << "www.example.com" if config.respond_to?(:hosts)
    # Specs run in an isolated app that does not define ApplicationController.
    # Use ActionController::Base as the CMS admin base in this environment.
    config.ruby_cms.admin_base_controller = "ActionController::Base"

    # RSpec controller specs call `self.routes = Rails.application.routes` first.
    # Default would load the gem's config/routes.rb and call Engine.routes.draw again,
    # duplicating route names. Use an empty application route set instead.
    minimal_routes = File.expand_path("minimal_routes.rb", __dir__)
    # Rails 8+: Path has no #clear; replace the routes file list in one assignment.
    config.paths["config/routes.rb"] = minimal_routes

    # BaseController defaults to layout "admin/admin" (host apps supply it). Specs use a stub layout here.
    config.paths["app/views"] << File.expand_path("dummy_app_views", __dir__)
  end
end

RubyCmsSpec::Application.initialize!
