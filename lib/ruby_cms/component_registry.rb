# frozen_string_literal: true

module RubyCms
  # Component Registry
  # Allows registering components (RubyUI, host components, primitives) for use in the CMS
  class ComponentRegistry
    Component = Struct.new(
      :key,
      :name,
      :category,
      :icon,
      :schema,
      :render,
      :slots,
      :dependencies,
      :description,
      keyword_init: true
    )

    def initialize
      @components = {}
      @categories = {}
    end

    # Register a component
    # @param key [String] Stable identifier (e.g. "ruby_ui.card", "layout.container")
    # @param name [String] Display name
    # @param category [String] Category for grouping (e.g. "Layout", "Content", "Forms")
    # @param icon [String] Optional icon identifier
    # @param schema [Hash] Props schema definition (JSON Schema format)
    # @param render [Proc] Render callable: ->(view_context, props, &block) { ... }
    # @param slots [Array<String>] Optional slot names this component accepts
    # @param dependencies [Array<String>] Optional component keys this component depends on
    # @param description [String] Optional description
    def register(key:, name:, category: "General", icon: nil, schema: {}, render: nil, slots: [],
                 dependencies: [], description: nil)
      raise ArgumentError, "Component key is required" if key.blank?
      raise ArgumentError, "Component name is required" if name.blank?
      raise ArgumentError, "Render callable is required" if render.nil? || !render.kind_of?(Proc)

      # Validate dependencies exist
      dependencies.each do |dep_key|
        unless registered?(dep_key)
          raise ArgumentError, "Component dependency '#{dep_key}' is not registered"
        end
      end

      component = Component.new(
        key: key.to_s,
        name: name,
        category: category,
        icon: icon,
        schema: schema,
        render: render || default_renderer(key),
        slots: slots,
        dependencies: dependencies,
        description: description
      )

      @components[key.to_s] = component
      @categories[category] ||= []
      @categories[category] << component unless @categories[category].include?(component)
    end

    # Get a component by key
    def get(key)
      @components[key.to_s]
    end

    # Check if a component is registered
    def registered?(key)
      @components.key?(key.to_s)
    end

    # Get all components, optionally filtered by category
    def all(category: nil)
      if category
        @categories[category] || []
      else
        @components.values
      end
    end

    # Get all categories
    def categories
      @categories.keys.sort
    end

    # Render a component
    # @param view_context [ActionView::Base] The view context
    # @param key [String] Component key
    # @param props [Hash] Component props
    # @param block [Proc] Optional block for children/slots
    # @param slot_content [Hash] Optional named slot content: { "header" => "...", "footer" => "..." }
    def render(view_context, key, props={}, slot_content: {}, &)
      component = get(key)
      raise ArgumentError, "Component not found: #{key}" unless component

      # Validate props against schema if provided
      validate_props(props, component.schema) if component.schema.present?

      # Validate slot content if component has slots
      if component.slots.present? && slot_content.present?
        slot_content.each_key do |slot_name|
          unless component.slots.include?(slot_name.to_s)
            raise ArgumentError, "Component '#{key}' does not accept slot '#{slot_name}'"
          end
        end
      end

      # Call the render proc with slot content available
      if slot_content.present?
        # If slots are provided, pass them as a second block parameter
        component.render.call(view_context, props) do |slot_name=:default|
          slot_content[slot_name.to_s] || (block_given? ? yield : "")
        end
      else
        # Standard rendering with block
        component.render.call(view_context, props, &)
      end
    end

    # Get components that depend on a given component
    # @param key [String] Component key
    # @return [Array<Component>] Components that depend on this one
    def dependents_of(key)
      @components.values.select {|c| c.dependencies.include?(key.to_s) }
    end

    # Check if a component can be used (all dependencies are available)
    # @param key [String] Component key
    # @param available_components [Array<String>] List of available component keys
    # @return [Boolean] True if all dependencies are available
    def can_use?(key, available_components=nil)
      component = get(key)
      return false unless component

      return true if component.dependencies.empty?

      available = available_components || @components.keys
      component.dependencies.all? {|dep| available.include?(dep.to_s) }
    end

    # Clear all registrations (useful for testing)
    def clear
      @components.clear
      @categories.clear
    end

    private

    # Default renderer that tries to find a RubyUI component or host component
    def default_renderer(key)
      lambda do |view_context, props, &block|
        # Try to find RubyUI component first
        component_class = find_ruby_ui_component(key)
        if component_class
          view_context.render(component_class.new(**props), &block)
        else
          # Try to find host component
          component_path = find_host_component_path(key)
          if component_path
            view_context.render(partial: component_path, locals: props, &block)
          else
            # Fallback: render as a div with the key as a class
            view_context.tag.div(class: "component-#{key}", data: { component_key: key }, &block)
          end
        end
      end
    end

    # Try to find a RubyUI component class
    def find_ruby_ui_component(key)
      # Convert "ruby_ui.card" to RubyUI::Card
      parts = key.to_s.split(".")
      return nil unless parts.first == "ruby_ui"

      component_name = parts[1..].map(&:camelize).join("::")
      class_name = "RubyUI::#{component_name}"

      begin
        class_name.constantize
      rescue NameError
        nil
      end
    end

    # Try to find a host component partial path
    def find_host_component_path(key)
      # Convert "layout.container" to "layouts/container" or "components/container"
      parts = key.to_s.split(".")
      return nil if parts.first == "ruby_ui"

      # Return the first likely path - Rails will handle missing partials
      parts.join("/").to_s
    end

    # Validate props against schema (basic implementation)
    def validate_props(props, schema)
      return if schema.blank?

      # Basic validation - check required fields
      if schema[:required].kind_of?(Array)
        schema[:required].each do |required_key|
          unless props.key?(required_key.to_s) || props.key?(required_key.to_sym)
            raise ArgumentError, "Required prop missing: #{required_key}"
          end
        end
      end

      # Type validation (simplified)
      return unless schema[:properties].kind_of?(Hash)

      schema[:properties].each do |prop_key, prop_schema|
        next unless props.key?(prop_key.to_s) || props.key?(prop_key.to_sym)

        value = props[prop_key.to_s] || props[prop_key.to_sym]

        # Skip validation for nil or empty string values (optional fields)
        next if value.nil? || (value.kind_of?(String) && value.empty?)

        expected_type = prop_schema[:type]

        next unless expected_type

        type_valid = case expected_type
                     when "string"
                       value.kind_of?(String)
                     when "number", "integer"
                       value.kind_of?(Numeric)
                     when "boolean"
                       value.kind_of?(TrueClass) || value.kind_of?(FalseClass)
                     when "array"
                       value.kind_of?(Array)
                     when "object"
                       value.kind_of?(Hash)
                     else
                       true # Unknown type, skip validation
                     end

        unless type_valid
          raise ArgumentError,
                "Prop #{prop_key} has wrong type. Expected #{expected_type}, got #{value.class}"
        end
      end
    end
  end

  # Global registry instance
  @component_registry = ComponentRegistry.new

  class << self
    attr_reader :component_registry

    # Register a component (convenience method)
    def register_component(**)
      @component_registry.register(**)
    end

    # Get a component
    def get_component(key)
      @component_registry.get(key)
    end

    # Check if registered
    def component_registered?(key)
      @component_registry.registered?(key)
    end

    # Get all components
    def all_components(category: nil)
      @component_registry.all(category:)
    end

    # Render a component
    def render_component(view_context, key, props={}, slot_content: {}, &)
      @component_registry.render(view_context, key, props, slot_content:, &)
    end
  end
end
