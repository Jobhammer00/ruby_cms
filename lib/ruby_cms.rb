# frozen_string_literal: true

require_relative "ruby_cms/version"
require_relative "ruby_cms/engine"
require_relative "ruby_cms/app_integration"
require_relative "ruby_cms/content_blocks_sync"

module RubyCms
  class Error < StandardError; end

  mattr_accessor :nav_registry
  self.nav_registry = []

  def self.configure
    yield(Rails.application.config.ruby_cms)
  end

  # Register a link for the admin navigation.
  # Options: key:, label:, path: (string or callable receiving the view), icon: (optional), section: (optional, for grouping), if: (optional callable to show/hide).
  def self.nav_register(key:, label:, path:, icon: nil, section: nil, **options)
    return if nav_registry.any? {|e| e[:key] == key }

    self.nav_registry += [
      {
        key: key, label: label, path: path, icon: icon, section: section,
        if: options[:if]
      }
    ]
  end

  # Navigation API: RubyCms::Nav.register(key:, label:, path:, icon: nil, section: nil, if: nil)
  module Nav
    def self.register(key:, label:, path:, icon: nil, section: nil, **)
      RubyCms.nav_register(key:, label:, path:, icon:, section:,
                           **)
    end
  end
end
