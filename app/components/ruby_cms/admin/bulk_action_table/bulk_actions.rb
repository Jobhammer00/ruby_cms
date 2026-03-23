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
            class: "hidden bg-primary/5 border-t border-border/60 px-5 py-3 backdrop-blur-sm",
            data: {
              "#{@controller_name}-target": "bulkBar"
            }
          ) do
            div(class: "flex items-center justify-between gap-4 max-w-full") do
              render_selection_info
              render_action_buttons
            end
          end
        end

        private

        def render_selection_info
          div(class: "flex items-center gap-3") do
            render_selection_left
            div(class: "h-4 w-px bg-border/60")
            render_selection_buttons
          end
        end

        def render_selection_left
          div(class: "flex items-center gap-2") do
            render_selected_count_badge
            span(class: "text-sm font-medium text-foreground") { "selected" }
          end
        end

        def render_selected_count_badge
          div(class: "size-6 rounded-full bg-primary/10 flex items-center justify-center") do
            span(
              class: "text-xs font-bold text-primary tabular-nums",
              data: {
                "#{@controller_name}-target": "selectedCount"
              }
            ) { "0" }
          end
        end

        def render_selection_buttons
          button(
            type: "button",
            class: "text-xs font-medium text-muted-foreground hover:text-foreground transition-colors",
            data: {
              "#{@controller_name}-target": "selectAllButton",
              action: "click->#{@controller_name}#selectAll"
            }
          ) { "Select all" }

          button(
            type: "button",
            class: "text-xs font-medium text-muted-foreground hover:text-foreground transition-colors",
            data: {
              action: "click->#{@controller_name}#clearSelection"
            }
          ) { "Clear" }
        end

        def render_action_buttons
          div(class: "flex items-center gap-2") do
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
          base = "inline-flex items-center justify-center rounded-md border border-border " \
                 "bg-white px-3 py-1.5 text-sm font-medium text-foreground shadow-sm " \
                 "hover:bg-muted transition-colors"
          config[:class].present? ? "#{base} #{config[:class]}" : base
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
            class: "inline-flex items-center justify-center rounded-md border border-destructive/30 " \
                   "bg-white px-3 py-1.5 text-sm font-medium text-destructive shadow-sm " \
                   "hover:bg-destructive/10 transition-colors",
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
