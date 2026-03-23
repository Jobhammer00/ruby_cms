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
          super
          @click_url = click_url
          @data = data || {}
          @cells = cells
          @bulk_actions_enabled = bulk_actions_enabled
          @controller_name = controller_name
          @row_class = binding.local_variable_get(:class)
          @user_attrs = user_attrs
        end

        def view_template(&block)
          tr(**row_attributes) do
            render_bulk_checkbox
            render_cells_or_block(&block)
          end
        end

        private

        def row_attributes
          {
            class: build_row_classes,
            data: (build_row_data_attributes || {}).merge(@data || {})
          }
        end

        def render_bulk_checkbox
          return unless @bulk_actions_enabled && @data&.[](:item_id)

          render BulkActionTableCheckboxCell.new(
            item_id: @data[:item_id],
            controller_name: @controller_name
          )
        end

        def render_cells_or_block(&block)
          if @cells.nil? && block
            # Block returns HTML from render partial - output as raw to avoid escaping
            return raw(yield) # rubocop:disable Rails/OutputSafety -- partial output is trusted
          end

          Array(@cells).each do |cell|
            if cell.kind_of?(Hash)
              td(class: cell[:class]) { cell[:content] }
            else
              td { cell }
            end
          end
        end

        def build_row_classes
          classes = ["border-b border-border/40 hover:bg-muted/50 transition-colors"]
          classes << @row_class if @row_class
          classes << "cursor-pointer" if @click_url
          build_classes(classes)
        end

        def build_row_data_attributes
          attrs = {}
          attrs[:item_id] = @data[:item_id] if @data[:item_id]

          if @click_url
            attrs[:click_url] = @click_url
            attrs[:action] = "click->#{@controller_name}#rowClick"
          end

          attrs
        end
      end
    end
  end
end
