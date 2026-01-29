# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Table header component
      # Renders <thead> with column headers and optional select-all checkbox
      #
      # @param headers [Array<String>] Array of header text
      # @param bulk_actions_enabled [Boolean] Whether to show select-all checkbox
      # @param controller_name [String] Stimulus controller identifier
      class BulkActionTableHeader < BaseComponent
        def initialize(
          headers: [],
          bulk_actions_enabled: true,
          controller_name: "ruby-cms--bulk-action-table"
        )
          super
          @headers = headers
          @bulk_actions_enabled = bulk_actions_enabled
          @controller_name = controller_name
        end

        def view_template
          thead(class: "bulk-action-table__header") do
            tr do
              render_bulk_checkbox_header
              render_table_headers
            end
          end
        end

        private

        def render_bulk_checkbox_header
          return unless @bulk_actions_enabled

          render BulkActionTableCheckboxHead.new(controller_name: @controller_name)
        end

        def render_table_headers
          Array(@headers).each do |header|
            if header.kind_of?(Hash)
              th(class: header[:class]) { header[:text] || header[:label] }
            else
              th { header }
            end
          end
        end
      end
    end
  end
end
