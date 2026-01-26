# frozen_string_literal: true

module RubyCms
  class ComponentRegistry
    # Register default/built-in components (primitives and common RubyUI components)
    module Defaults
      def self.register_all
        registry = RubyCms.component_registry

        # Layout Primitives
        registry.register(
          key: "primitive.div",
          name: "Div",
          category: "Layout",
          description: "A simple div container",
          schema: {
            type: "object",
            properties: {
              class: { type: "string", default: "" },
              id: { type: "string", default: "" }
            }
          },
          render: lambda do |view, props, &block|
            classes = props[:class] || props["class"] || ""
            id_attr = props[:id] || props["id"]
            view.tag.div(class: classes, id: id_attr, &block)
          end
        )

        registry.register(
          key: "primitive.container",
          name: "Container",
          category: "Layout",
          description: "A container with max-width and padding",
          schema: {
            type: "object",
            properties: {
              max_width: { type: "string", default: "7xl" },
              padding: { type: "string", default: "4" }
            }
          },
          render: lambda do |view, props, &block|
            max_width = props[:max_width] || props["max_width"] || "7xl"
            padding = props[:padding] || props["padding"] || "4"
            view.tag.div(class: "max-w-#{max_width} mx-auto px-#{padding}", &block)
          end
        )

        registry.register(
          key: "primitive.section",
          name: "Section",
          category: "Layout",
          description: "A section with vertical spacing",
          schema: {
            type: "object",
            properties: {
              padding: { type: "string", default: "py-12" }
            }
          },
          render: lambda do |view, props, &block|
            padding = props[:padding] || props["padding"] || "py-12"
            view.tag.section(class: padding, &block)
          end
        )

        registry.register(
          key: "primitive.stack",
          name: "Stack",
          category: "Layout",
          description: "Vertical stack with gap",
          schema: {
            type: "object",
            properties: {
              gap: { type: "string", default: "4" }
            }
          },
          render: lambda do |view, props, &block|
            gap = props[:gap] || props["gap"] || "4"
            view.tag.div(class: "flex flex-col gap-#{gap}", &block)
          end
        )

        registry.register(
          key: "primitive.grid",
          name: "Grid",
          category: "Layout",
          description: "Responsive grid layout",
          schema: {
            type: "object",
            properties: {
              columns: { type: "string", default: "3" }
            }
          },
          render: lambda do |view, props, &block|
            columns = props[:columns] || props["columns"] || "3"
            view.tag.div(class: "grid grid-cols-1 md:grid-cols-#{columns} gap-4", &block)
          end
        )

        # Content Primitives
        registry.register(
          key: "primitive.heading",
          name: "Heading",
          category: "Content",
          description: "Heading text",
          schema: {
            type: "object",
            required: ["text"],
            properties: {
              text: { type: "string" },
              level: { type: "string", default: "h1" },
              size: { type: "string", default: "text-3xl" }
            }
          },
          render: lambda do |view, props, &_block|
            text = props[:text] || props["text"] || ""
            level = props[:level] || props["level"] || "h1"
            size = props[:size] || props["size"] || "text-3xl"
            view.tag.send(level.to_sym, text, class: "#{size} font-bold")
          end
        )

        registry.register(
          key: "primitive.text",
          name: "Text",
          category: "Content",
          description: "Paragraph text",
          schema: {
            type: "object",
            required: ["text"],
            properties: {
              text: { type: "string" }
            }
          },
          render: lambda do |view, props, &_block|
            text = props[:text] || props["text"] || ""
            view.tag.p(text, class: "text-gray-700")
          end
        )

        # Try to register RubyUI components if available
        if defined?(RubyUI)
          begin
            RubyCms::PageBuilder::RubyUIDiscovery.register_components(registry)
          rescue => e
            # Silently fail if RubyUI is not properly configured
            Rails.logger.debug("RubyUI components not available: #{e.message}") if defined?(Rails.logger)
          end
        end
      end
    end
  end
end
