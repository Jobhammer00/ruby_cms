# frozen_string_literal: true

module RubyCms
  module PageBuilder
    # Discovers and registers RubyUI components automatically
    #
    # This class automatically discovers RubyUI components from the host application's
    # app/components/ruby_ui/ directory and registers them for use in the page builder.
    #
    # Components are organized by category and include full schema definitions
    # for their props, allowing the page builder to render appropriate form controls.
    class RubyUIDiscovery
      # Components to automatically discover and register, organized by category
      # Each component maps to its schema definition
      COMPONENT_SCHEMAS = {
        # Forms category
        "Button" => {
          category: "Forms",
          description: "A clickable button",
          has_content: true,
          schema: {
            type: "object",
            properties: {
              content_block_key: {
                type: "string",
                description: "Content block key for the button text (editable in Visual Editor)",
                format: "content_block"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },
        "Input" => {
          category: "Forms",
          description: "A text input field",
          schema: {
            type: "object",
            properties: {
              placeholder: {
                type: "string",
                description: "Placeholder text"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },
        "Textarea" => {
          category: "Forms",
          description: "A multi-line text input",
          schema: {
            type: "object",
            properties: {
              placeholder: {
                type: "string",
                description: "Placeholder text"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },

        # Navigation category
        "Link" => {
          category: "Navigation",
          description: "A styled link",
          has_content: true,
          schema: {
            type: "object",
            properties: {
              content_block_key: {
                type: "string",
                description: "Content block key for the link text (editable in Visual Editor)",
                format: "content_block"
              },
              href: {
                type: "string",
                description: "The URL the link points to"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },

        # Typography category
        "Heading" => {
          category: "Typography",
          description: "A heading element (h1-h6)",
          has_content: true,
          schema: {
            type: "object",
            properties: {
              content_block_key: {
                type: "string",
                description: "Content block key for the heading text (editable in Visual Editor)",
                format: "content_block"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },
        "Text" => {
          category: "Typography",
          description: "A paragraph or span of text",
          has_content: true,
          schema: {
            type: "object",
            properties: {
              content_block_key: {
                type: "string",
                description: "Content block key for the text content (editable in Visual Editor)",
                format: "content_block"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },
        "InlineCode" => {
          category: "Typography",
          description: "Inline code snippet",
          has_content: true,
          schema: {
            type: "object",
            properties: {
              content_block_key: {
                type: "string",
                description: "Content block key for the code text (editable in Visual Editor)",
                format: "content_block"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },
        "InlineLink" => {
          category: "Typography",
          description: "An inline text link",
          has_content: true,
          schema: {
            type: "object",
            properties: {
              content_block_key: {
                type: "string",
                description: "Content block key for the link text (editable in Visual Editor)",
                format: "content_block"
              },
              href: {
                type: "string",
                description: "The URL the link points to"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },

        # Layout category
        "Card" => {
          category: "Layout",
          description: "A card container with rounded corners and shadow",
          schema: {
            type: "object",
            properties: {}
          }
        },
        "CardHeader" => {
          category: "Layout",
          description: "Header section of a card",
          schema: {
            type: "object",
            properties: {}
          }
        },
        "CardTitle" => {
          category: "Layout",
          description: "Title element within a card header",
          has_content: true,
          schema: {
            type: "object",
            properties: {
              content_block_key: {
                type: "string",
                description: "Content block key for the card title (editable in Visual Editor)",
                format: "content_block"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },
        "CardDescription" => {
          category: "Layout",
          description: "Description text within a card header",
          has_content: true,
          schema: {
            type: "object",
            properties: {
              content_block_key: {
                type: "string",
                description: "Content block key for the card description (editable in Visual Editor)",
                format: "content_block"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },
        "CardContent" => {
          category: "Layout",
          description: "Main content area of a card",
          schema: {
            type: "object",
            properties: {}
          }
        },
        "CardFooter" => {
          category: "Layout",
          description: "Footer section of a card",
          schema: {
            type: "object",
            properties: {}
          }
        },

        # Interactive category
        "Tooltip" => {
          category: "Interactive",
          description: "A tooltip container",
          schema: {
            type: "object",
            properties: {}
          }
        },
        "TooltipTrigger" => {
          category: "Interactive",
          description: "Element that triggers a tooltip on hover",
          schema: {
            type: "object",
            properties: {}
          }
        },
        "TooltipContent" => {
          category: "Interactive",
          description: "Content displayed in the tooltip",
          has_content: true,
          schema: {
            type: "object",
            properties: {
              content_block_key: {
                type: "string",
                description: "Content block key for the tooltip text (editable in Visual Editor)",
                format: "content_block"
              },
              class: {
                type: "string",
                description: "Additional CSS classes (optional)"
              },
              style: {
                type: "string",
                description: "Inline CSS styles (optional)"
              }
            }
          }
        },
        "ThemeToggle" => {
          category: "Interactive",
          description: "Dark/light mode toggle button",
          schema: {
            type: "object",
            properties: {}
          }
        }
      }.freeze

      class << self
        # Discover all available RubyUI components
        # @return [Array<Hash>] Array of component definitions
        def discover_components
          return [] unless ruby_ui_available?

          components = []
          COMPONENT_SCHEMAS.each do |name, config|
            component_key = "ruby_ui.#{name.underscore}"
            component_class = find_component_class(name)

            next unless component_class

            # Use schema as-is without merging common attributes
            # This prevents validation errors for optional nil values
            schema = config[:schema].deep_dup
            schema[:properties] ||= {}

            components << {
              key: component_key,
              name: name.titleize,
              category: config[:category],
              description: config[:description],
              schema: schema,
              render: build_render_proc(component_class)
            }
          end

          components
        end

        # Register discovered components with the registry
        # @param registry [RubyCms::ComponentRegistry] The component registry
        def register_components(registry)
          discover_components.each do |comp_def|
            registry.register(**comp_def)
          end
        end

        # Check if RubyUI is available
        # @return [Boolean] True if RubyUI module is defined
        def ruby_ui_available?
          defined?(RubyUI) && RubyUI.const_defined?(:Base, false)
        end

        # Get the schema for a specific component
        # @param component_name [String] The component name (e.g., "Button")
        # @return [Hash] The schema for the component
        def schema_for(component_name)
          config = COMPONENT_SCHEMAS[component_name]
          return nil unless config

          schema = config[:schema].deep_dup
          schema[:properties] ||= {}
          schema
        end

        # Fetch the text content from a content block
        # @param key [String] The content block key
        # @return [String] The content text, or empty string if not found
        def fetch_content_block_text(key)
          return "" if key.blank?

          content_block = RubyCms::ContentBlock.find_by(key: key)
          return "" unless content_block

          # Return the content, preferring plain text for inline components
          content_block.content.to_s
        rescue StandardError
          ""
        end

        private

        def find_component_class(name)
          # Try to find the component class using Rails autoloading
          class_name = "RubyUI::#{name}"

          # First try constantizing directly
          class_name.constantize
        rescue NameError
          # If that fails, try to find it in the host app's components directory
          find_in_host_app(name)
        end

        def find_in_host_app(name)
          return nil unless defined?(Rails)

          # Map component names to their subdirectories
          subdirectory_map = {
            "Text" => "typography",
            "Heading" => "typography",
            "InlineCode" => "typography",
            "InlineLink" => "typography",
            "TypographyBlockquote" => "typography",
            "Card" => "card",
            "CardHeader" => "card",
            "CardTitle" => "card",
            "CardDescription" => "card",
            "CardContent" => "card",
            "CardFooter" => "card",
            "Tooltip" => "tooltip",
            "TooltipTrigger" => "tooltip",
            "TooltipContent" => "tooltip",
            "ThemeToggle" => "theme_toggle",
            "SetDarkMode" => "theme_toggle",
            "SetLightMode" => "theme_toggle",
            "Select" => "select",
            "SelectTrigger" => "select",
            "SelectValue" => "select",
            "SelectContent" => "select",
            "SelectGroup" => "select",
            "SelectLabel" => "select",
            "SelectItem" => "select",
            "SelectInput" => "select",
            "Form" => "form",
            "FormField" => "form",
            "FormFieldLabel" => "form",
            "FormFieldHint" => "form",
            "FormFieldError" => "form"
          }

          subdirectory = subdirectory_map[name]
          underscore_name = name.underscore

          # Build list of paths to check
          component_paths = []
          if subdirectory
            component_paths << Rails.root.join("app", "components", "ruby_ui", subdirectory, "#{underscore_name}.rb")
          end
          component_paths << Rails.root.join("app", "components", "ruby_ui", underscore_name, "#{underscore_name}.rb")
          component_paths << Rails.root.join("app", "components", "ruby_ui", "#{underscore_name}.rb")

          component_path = component_paths.find(&:exist?)

          if component_path
            # Try to constantize again after the file might be loaded
            "RubyUI::#{name}".constantize
          else
            nil
          end
        rescue NameError, LoadError
          nil
        end

        def build_render_proc(component_class)
          lambda do |view, props = {}, &block|
            # RubyUI components are Phlex components, render them directly
            # Convert string keys to symbol keys for component initialization
            # Filter out empty/nil values
            symbolized_props = {}
            content_block_key = nil

            props.each do |key, value|
              next if value.nil? || value == ""

              sym_key = key.to_sym

              # Extract content_block_key for text content
              if sym_key == :content_block_key
                content_block_key = value
                next
              end

              symbolized_props[sym_key] = value
            end

            # If a content_block_key is provided, fetch the content and use it as the block content
            if content_block_key.present?
              content_text = RubyCms::PageBuilder::RubyUIDiscovery.fetch_content_block_text(content_block_key)
              view.render(component_class.new(**symbolized_props)) { content_text }
            else
              view.render(component_class.new(**symbolized_props), &block)
            end
          end
        end
      end
    end
  end
end
