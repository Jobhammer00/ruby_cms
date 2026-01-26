# frozen_string_literal: true

module RubyCms
  module ApplicationHelper
    # Expose the engine's route helpers (ruby_cms_admin_*_path) in views.
    include RubyCms::Engine.routes.url_helpers

    def ruby_cms_nav_entries
      RubyCms.nav_registry.select do |e|
        next false if e[:if].present? && (!e[:if].respond_to?(:call) || !e[:if].call(self))

        true
      end
    end
  end
end
