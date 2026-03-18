# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Checkbox cell component
      # Renders checkbox in table row for bulk selection
      #
      # @param item_id [Integer, String] Item ID for checkbox value
      # @param controller_name [String] Stimulus controller identifier
      class BulkActionTableCheckboxCell < BaseComponent
        def initialize(
          item_id:,
          controller_name: "ruby-cms--bulk-action-table"
        )
          super
          @item_id = item_id
          @controller_name = controller_name
        end

        def view_template
          td(class: "w-12 px-6 py-3",
             data: { action: "click->#{@controller_name}#stopPropagation" }) do
            input(
              type: "checkbox",
              role: "checkbox",
              value: @item_id,
              class: "h-4 w-4 rounded border-gray-300 text-teal-600 focus:ring-teal-200",
              data: {
                "#{@controller_name}-target": "itemCheckbox",
                item_id: @item_id,
                action: "change->#{@controller_name}#updateSelection"
              },
              aria_label: "Select row"
            )
          end
        end
      end
    end
  end
end
