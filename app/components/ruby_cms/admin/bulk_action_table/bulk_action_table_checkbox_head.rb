# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Checkbox header cell component
      # Renders select-all checkbox in table header
      #
      # @param controller_name [String] Stimulus controller identifier
      class BulkActionTableCheckboxHead < BaseComponent
        def initialize(controller_name: "ruby-cms--bulk-action-table")
          super()
          @controller_name = controller_name
        end

        def view_template
          th(class: "w-12 px-6 py-3") do
            input(
              type: "checkbox",
              role: "checkbox",
              class: "h-4 w-4 rounded border-gray-300 text-teal-600 focus:ring-teal-200",
              data: {
                "#{@controller_name}-target": "selectAllCheckbox",
                action: "change->#{@controller_name}#toggleSelectAll"
              },
              aria_label: "Select all"
            )
          end
        end
      end
    end
  end
end
