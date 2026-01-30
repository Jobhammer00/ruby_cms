# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Bulk actions bar component
      # Appears when items are selected, shows selected count and action buttons
      #
      # @param controller_name [String] Stimulus controller identifier
      # @param item_name [String] Singular name for items
      # @param bulk_actions_url [String, nil] URL for bulk delete action
      # @param bulk_action_buttons [Array<Hash>] Array of custom bulk action button configs
      class BulkActions < BaseComponent
        def initialize(
          controller_name: "ruby-cms--bulk-action-table",
          item_name: "item",
          bulk_actions_url: nil,
          bulk_action_buttons: []
        )
          super
          @controller_name = controller_name
          @item_name = item_name
          @bulk_actions_url = bulk_actions_url
          @bulk_action_buttons = bulk_action_buttons || []
        end

        def view_template
          div(
            class: "bulk-actions-bar",
            data: {
              "#{@controller_name}-target": "bulkBar"
            }
          ) do
            div(class: "bulk-actions-bar__content") do
              render_selection_info
              render_action_buttons
            end
          end
        end

        private

        def render_selection_info
          div(class: "bulk-actions-bar__selection-info") do
            span(
              class: "bulk-actions-bar__selected-count",
              data: {
                "#{@controller_name}-target": "selectedCount"
              }
            ) { "0 #{@item_name}s selected:" }
            button(
              type: "button",
              class: "bulk-actions-bar__select-all-button",
              data: {
                "#{@controller_name}-target": "selectAllButton",
                action: "click->#{@controller_name}#selectAll"
              }
            ) { "Select all" }
            button(
              type: "button",
              class: "bulk-actions-bar__clear-button",
              data: {
                action: "click->#{@controller_name}#clearSelection"
              }
            ) { "Clear selection" }
          end
        end

        def render_action_buttons
          div(class: "bulk-actions-bar__buttons") do
            @bulk_action_buttons.each do |button_config|
              render_custom_action_button(button_config)
            end

            render_delete_button if @bulk_actions_url
          end
        end

        def render_custom_action_button(config)
          label = config[:label] || config[:text] || config[:name]&.humanize || "Button"
          action_name = config[:name] || config[:action_name]

          button(
            type: "button",
            class: build_button_class(config),
            data: build_button_data_attrs(config, label, action_name)
          ) { label }
        end

        def build_button_class(config)
          classes = ["bulk-action-button"]
          classes << config[:class] if config[:class].present?
          classes.join(" ")
        end

        def build_button_data_attrs(config, label, action_name)
          data_attrs = {
            action: "click->#{@controller_name}#showActionDialog",
            action_name: action_name,
            action_url: config[:url]&.to_s,
            action_label: label
          }

          # Pass through action_type
          data_attrs[:action_type] = config[:action_type] if config[:action_type].present?

          data_attrs[:action_confirm] = config[:confirm] if config[:confirm].present?

          data_attrs
        end

        def render_delete_button
          button(
            type: "button",
            class: "bulk-action-button bulk-action-button--delete",
            data: {
              action: "click->#{@controller_name}#showActionDialog",
              action_name: "delete",
              action_label: "Delete Selected",
              action_confirm: "Are you sure you want to delete the selected \
               items? This action cannot be undone.",
              action_url: @bulk_actions_url&.to_s
            }
          ) { "Delete Selected" }
        end
      end
    end
  end
end
