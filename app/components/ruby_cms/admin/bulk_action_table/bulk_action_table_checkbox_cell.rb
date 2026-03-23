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
          td(class: "w-10 px-4 py-3",
             data: { action: "click->#{@controller_name}#stopPropagation" }) do
            div(class: "inline-flex items-center justify-center") do
              input(
                type: "checkbox",
                role: "checkbox",
                value: @item_id,
                class: "size-4 rounded border-border/80 text-primary focus:ring-primary/30 focus:ring-offset-0 cursor-pointer transition-colors",
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
end
