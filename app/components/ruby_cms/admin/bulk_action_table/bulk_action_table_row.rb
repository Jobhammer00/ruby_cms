# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Table row component
      # Individual table row with clickable support and checkbox
      #
      # @param click_url [String, nil] URL to navigate when row is clicked
      # @param data [Hash] Data attributes (e.g., { item_id: 1 })
      # @param cells [Array, nil] Array of cell content (alternative to block)
      # @param bulk_actions_enabled [Boolean] Whether to show checkbox cell
      # @param controller_name [String] Stimulus controller identifier
      # @param class [String, nil] Additional CSS classes
      class BulkActionTableRow < BaseComponent
        def initialize(
          click_url: nil,
          data: {},
          cells: nil,
          bulk_actions_enabled: true,
          controller_name: "ruby-cms--bulk-action-table",
          class: nil,
          **user_attrs
        )
          @click_url = click_url
          @data = data || {}
          @cells = cells
          @bulk_actions_enabled = bulk_actions_enabled
          @controller_name = controller_name
          @row_class = binding.local_variable_get(:class)
          @user_attrs = user_attrs
        end

        def view_template
          base_data = build_row_data_attributes
          # Merge @data into base_data, but don't override built attributes
          merged_data = base_data.merge(@data || {})

          row_attributes = {
            class: build_row_classes,
            data: merged_data
          }

          tr(**row_attributes) do
            if @bulk_actions_enabled && @data[:item_id]
              render BulkActionTableCheckboxCell.new(
                item_id: @data[:item_id],
                controller_name: @controller_name
              )
            end

            if @cells
              @cells.each do |cell|
                if cell.kind_of?(Hash)
                  td(class: cell[:class]) { cell[:content] }
                else
                  td { cell }
                end
              end
            elsif block_given?
              yield
            end
          end
        end

        private

        def build_row_classes
          classes = ["bulk-action-table__row"]
          classes << @row_class if @row_class
          classes << "bulk-action-table__row--clickable" if @click_url
          build_classes(classes)
        end

        def build_row_data_attributes
          attrs = {}
          attrs[:item_id] = @data[:item_id] if @data[:item_id]

          if @click_url
            attrs[:controller] = "clickable-row"
            attrs[:clickable_row_click_url_value] = @click_url
            attrs[:action] = "click->clickable-row#navigate"
          end

          attrs
        end
      end
    end
  end
end
