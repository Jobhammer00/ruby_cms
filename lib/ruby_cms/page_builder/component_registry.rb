# frozen_string_literal: true

module RubyCms
  module PageBuilder
    # Page Builder specific component registry extensions
    # This module provides additional functionality for page builder components
    module ComponentRegistry
      # Get all components available for the page builder
      # @return [Array<Component>] All registered components
      def self.all_components
        RubyCms.component_registry.all_components
      end

      # Get components grouped by category
      # @return [Hash<String, Array<Component>>] Components grouped by category
      def self.components_by_category
        all_components.group_by(&:category)
      end

      # Check if RubyUI components are available
      # @return [Boolean] True if RubyUI is defined and available
      def self.ruby_ui_available?
        defined?(RubyUI)
      end

      # Get only RubyUI components
      # @return [Array<Component>] RubyUI components only
      def self.ruby_ui_components
        all_components.select { |c| c.key.start_with?("ruby_ui.") }
      end

      # Get only primitive components
      # @return [Array<Component>] Primitive components only
      def self.primitive_components
        all_components.select { |c| c.key.start_with?("primitive.") }
      end
    end
  end
end
