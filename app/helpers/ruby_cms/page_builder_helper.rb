# frozen_string_literal: true

module RubyCms
  module PageBuilderHelper
    # Generate a form field from a JSON schema property
    def schema_field_for(property_key, property_schema, current_value = nil)
      field_name = "props[#{property_key}]"
      field_id = "prop_#{property_key}"
      property_schema[:title] || property_key.humanize
      field_type = property_schema[:type]
      default_value = property_schema[:default]
      value = current_value || default_value

      case field_type
      when "string"
        if property_schema[:enum]
          # Select dropdown
          select_tag field_name,
                     options_for_select(property_schema[:enum].map { |v| [v, v] }, value),
                     id: field_id,
                     class: "ruby_cms-select block w-full rounded-md border border-gray-300 px-3 py-2"
        elsif property_schema[:format] == "textarea" || (property_schema[:maxLength] && property_schema[:maxLength] > 100)
          # Textarea for long strings
          text_area_tag field_name, value,
                        id: field_id,
                        rows: property_schema[:rows] || 4,
                        class: "ruby_cms-textarea block w-full rounded-md border border-gray-300 px-3 py-2",
                        placeholder: property_schema[:placeholder]
        else
          # Regular text input
          text_field_tag field_name, value,
                         id: field_id,
                         class: "ruby_cms-input block w-full rounded-md border border-gray-300 px-3 py-2",
                         placeholder: property_schema[:placeholder]
        end
      when "number", "integer"
        number_field_tag field_name, value,
                         id: field_id,
                         class: "ruby_cms-input block w-full rounded-md border border-gray-300 px-3 py-2",
                         step: field_type == "integer" ? 1 : (property_schema[:step] || "any"),
                         min: property_schema[:minimum],
                         max: property_schema[:maximum]
      when "boolean"
        check_box_tag field_name, "1", value,
                      id: field_id,
                      class: "h-4 w-4 rounded border-gray-300"
      when "array"
        # Simple array input - comma-separated or JSON
        text_area_tag field_name, value.is_a?(Array) ? value.join(", ") : value.to_s,
                      id: field_id,
                      rows: 3,
                      class: "ruby_cms-textarea block w-full rounded-md border border-gray-300 px-3 py-2 font-mono text-sm",
                      placeholder: "Comma-separated values or JSON array"
      when "object"
        # Nested object - JSON textarea
        text_area_tag field_name, value.is_a?(Hash) ? JSON.pretty_generate(value) : value.to_s,
                      id: field_id,
                      rows: 6,
                      class: "ruby_cms-textarea block w-full rounded-md border border-gray-300 px-3 py-2 font-mono text-sm",
                      placeholder: "JSON object"
      else
        # Fallback: text input
        text_field_tag field_name, value,
                       id: field_id,
                       class: "ruby_cms-input block w-full rounded-md border border-gray-300 px-3 py-2"
      end
    end

    # Generate a complete form from a component schema
    def schema_form_for(component, current_props = {})
      unless component&.schema.present?
        return content_tag(:p, "No schema defined for this component.",
                           class: "text-sm text-gray-500")
      end

      schema = component.schema
      properties = schema[:properties] || {}
      required_fields = schema[:required] || []

      content_tag(:div, class: "space-y-4") do
        properties.map do |key, prop_schema|
          content_tag(:div, class: "ruby_cms-field") do
            label = content_tag(:label,
                                (prop_schema[:title] || key.humanize) + (required_fields.include?(key.to_s) || required_fields.include?(key.to_sym) ? " *" : ""),
                                class: "block text-sm font-medium text-gray-700 mb-1",
                                for: "prop_#{key}")
            field = schema_field_for(key, prop_schema, current_props[key.to_s] || current_props[key.to_sym])
            description = if prop_schema[:description]
                            content_tag(:p, prop_schema[:description],
                                        class: "mt-1 text-xs text-gray-500")
                          else
                            "".html_safe
                          end

            label + field + description
          end
        end.join.html_safe
      end
    end
  end
end
