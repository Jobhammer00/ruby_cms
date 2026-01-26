# frozen_string_literal: true

module RubyCms
  # Template Registry for Page Builder
  # Allows registering page templates for quick creation
  class TemplateRegistry
    Template = Struct.new(
      :key,
      :name,
      :description,
      :layout,
      :regions,
      :default_props,
      :content_block_keys,
      keyword_init: true
    )

    def initialize
      @templates = {}
    end

    # Register a template
    # @param key [String] Template identifier (e.g. "landing/simple", "blog/post")
    # @param name [String] Display name
    # @param description [String] Optional description
    # @param layout [String] Optional layout name
    # @param regions [Array<Hash>] Array of region definitions: [{ key: "main", nodes: [...] }]
    # @param default_props [Hash] Default props for nodes
    # @param content_block_keys [Array<String>] Content block keys to create
    def register(key:, name:, description: nil, layout: nil, regions: [], default_props: {}, content_block_keys: [])
      raise ArgumentError, "Template key is required" if key.blank?
      raise ArgumentError, "Template name is required" if name.blank?

      template = Template.new(
        key: key.to_s,
        name: name,
        description: description,
        layout: layout,
        regions: regions,
        default_props: default_props,
        content_block_keys: content_block_keys
      )

      @templates[key.to_s] = template
    end

    # Get a template by key
    def get(key)
      @templates[key.to_s]
    end

    # Check if a template is registered
    def registered?(key)
      @templates.key?(key.to_s)
    end

    # Get all templates
    def all
      @templates.values
    end

    # Create a page from a template
    # @param page [RubyCms::Page] The page to populate
    # @param template_key [String] Template key
    # @return [RubyCms::Page] The populated page
    def apply_to_page(page, template_key)
      template = get(template_key)
      raise ArgumentError, "Template not found: #{template_key}" unless template

      # Set render_mode to builder if template has regions, otherwise template mode
      if template.regions.any?
        page.render_mode = "builder"
      elsif template.layout.present?
        page.render_mode = "template"
        page.template_path = template.layout
      end

      # Set layout (for builder/html modes) if provided
      page.layout = template.layout if template.layout.present? && page.layout.blank?

      # Create regions and nodes (only for builder mode)
      if page.builder_mode?
        template.regions.each do |region_def|
          region = page.region(region_def[:key] || region_def["key"])
          region.update(position: region_def[:position] || region_def["position"] || 0)

          # Create nodes for this region
          nodes = region_def[:nodes] || region_def["nodes"] || []
          nodes.each_with_index do |node_def, index|
            component_key = node_def[:component_key] || node_def["component_key"]
            next unless component_key

            # Merge default props with node-specific props
            node_props = (template.default_props || {}).merge(node_def[:props] || node_def["props"] || {})

            region.page_nodes.create!(
              component_key: component_key,
              props: node_props,
              position: index
            )
          end
        end
      end

      # Create content blocks if specified
      template.content_block_keys.each do |block_key|
        RubyCms::ContentBlock.find_or_create_by(key: block_key) do |block|
          block.title = block_key.humanize
          block.content_type = "text"
          block.published = true
        end
      end

      page
    end

    # Clear all registrations (useful for testing)
    def clear
      @templates.clear
    end
  end

  # Global registry instance
  @template_registry = TemplateRegistry.new

  class << self
    attr_reader :template_registry

    # Register a template (convenience method)
    def register_template(**kwargs)
      @template_registry.register(**kwargs)
    end

    # Get a template
    def get_template(key)
      @template_registry.get(key)
    end

    # Check if registered
    def template_registered?(key)
      @template_registry.registered?(key)
    end

    # Get all templates
    def all_templates
      @template_registry.all
    end

    # Apply template to page
    def apply_template_to_page(page, template_key)
      @template_registry.apply_to_page(page, template_key)
    end
  end
end
