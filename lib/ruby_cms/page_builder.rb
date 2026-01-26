# frozen_string_literal: true

module RubyCms
  # Page Builder module - handles all page builder functionality
  #
  # This module organizes all page builder related functionality:
  # - Component discovery and registration
  # - RubyUI integration
  # - Component schemas and rendering
  #
  # File structure:
  # - app/controllers/ruby_cms/admin/page_builder_controller.rb
  # - app/helpers/ruby_cms/page_builder_helper.rb
  # - app/views/ruby_cms/admin/page_builder/
  # - app/javascript/controllers/ruby_cms/page_builder_controller.js
  # - lib/ruby_cms/page_builder/ (this module)
  module PageBuilder
    autoload :ComponentRegistry, "ruby_cms/page_builder/component_registry"
    autoload :RubyUIDiscovery, "ruby_cms/page_builder/ruby_ui_discovery"
  end
end
