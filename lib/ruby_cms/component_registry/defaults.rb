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
              class: { type: "string", default: "" },
              max_width: { type: "string", default: "" },
              padding: { type: "string", default: "" }
            }
          },
          render: lambda do |view, props, &block|
            classes = props[:class] || props["class"] || ""
            max_width = props[:max_width] || props["max_width"]
            padding = props[:padding] || props["padding"]

            style_parts = []
            style_parts << "max-width: #{max_width}" if max_width.present?
            if padding.present?
              style_parts << "padding-left: #{padding}"
              style_parts << "padding-right: #{padding}"
            end

            attrs = {}
            attrs[:class] = classes if classes.present?
            attrs[:style] = style_parts.join("; ") if style_parts.any?

            view.tag.div(**attrs, &block)
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
              class: { type: "string", default: "" },
              padding: { type: "string", default: "" }
            }
          },
          render: lambda do |view, props, &block|
            classes = props[:class] || props["class"] || ""
            padding = props[:padding] || props["padding"]

            style_parts = []
            if padding.present?
              style_parts << "padding-top: #{padding}"
              style_parts << "padding-bottom: #{padding}"
            end

            attrs = {}
            attrs[:class] = classes if classes.present?
            attrs[:style] = style_parts.join("; ") if style_parts.any?

            view.tag.section(**attrs, &block)
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
              class: { type: "string", default: "" },
              gap: { type: "string", default: "" }
            }
          },
          render: lambda do |view, props, &block|
            classes = props[:class] || props["class"] || ""
            gap = props[:gap] || props["gap"]

            style_parts = []
            if gap.present?
              style_parts << "display: flex"
              style_parts << "flex-direction: column"
              style_parts << "gap: #{gap}"
            end

            attrs = {}
            attrs[:class] = classes if classes.present?
            attrs[:style] = style_parts.join("; ") if style_parts.any?

            view.tag.div(**attrs, &block)
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
              class: { type: "string", default: "" },
              columns: { type: "string", default: "" },
              gap: { type: "string", default: "" }
            }
          },
          render: lambda do |view, props, &block|
            classes = props[:class] || props["class"] || ""
            columns = props[:columns] || props["columns"]
            gap = props[:gap] || props["gap"]

            style_parts = []
            style_parts << "display: grid"
            style_parts << "grid-template-columns: repeat(#{columns}, 1fr)" if columns.present?
            style_parts << "gap: #{gap}" if gap.present?

            attrs = {}
            attrs[:class] = classes if classes.present?
            attrs[:style] = style_parts.join("; ") if style_parts.any?

            view.tag.div(**attrs, &block)
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
              class: { type: "string", default: "" }
            }
          },
          render: lambda do |view, props, &_block|
            text = props[:text] || props["text"] || ""
            level = props[:level] || props["level"] || "h1"
            classes = props[:class] || props["class"] || ""

            attrs = {}
            attrs[:class] = classes if classes.present?

            view.tag.send(level.to_sym, text, **attrs)
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
              text: { type: "string" },
              class: { type: "string", default: "" }
            }
          },
          render: lambda do |view, props, &_block|
            text = props[:text] || props["text"] || ""
            classes = props[:class] || props["class"] || ""

            attrs = {}
            attrs[:class] = classes if classes.present?

            view.tag.p(text, **attrs)
          end
        )
      end
    end
  end
end
