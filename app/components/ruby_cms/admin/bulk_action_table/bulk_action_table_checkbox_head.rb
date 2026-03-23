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
          th(class: "w-10 px-4 py-3") do
            div(class: "inline-flex items-center justify-center") do
              input(
                type: "checkbox",
                role: "checkbox",
                class: "size-4 rounded border-border/80 text-primary focus:ring-primary/30 focus:ring-offset-0 cursor-pointer transition-colors",
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
end
