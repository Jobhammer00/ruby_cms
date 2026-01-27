# frozen_string_literal: true

module RubyCms
  module BulkActionTableHelper
    # Render the bulk action table delete dialog
    # @param controller_name [String] The Stimulus controller name (default: "ruby-cms--bulk-action-table")
    # @return [String] Rendered HTML for the delete dialog
    def render_bulk_action_table_delete_dialog(controller_name: "ruby-cms--bulk-action-table")
      render partial: "ruby_cms/admin/shared/bulk_action_table_delete_dialog",
             locals: { controller_name: }
    end

    # Render bulk actions bar (selection info and action buttons)
    # @param controller_name [String] The Stimulus controller name
    # @param item_name [String] The name of items being selected (e.g., "item", "content block")
    # @param bulk_actions_url [String] The URL for bulk actions
    # @param bulk_action_buttons [Array<Hash>] Array of button configs for bulk actions
    # @return [String] Rendered HTML for bulk actions bar
    def render_bulk_actions_bar(
      controller_name: "ruby-cms--bulk-action-table",
      item_name: "item",
      bulk_actions_url: nil,
      bulk_action_buttons: []
    )
      content_tag :div,
                  data: { "#{controller_name}_target": "bulkBar" },
                  class: "flex-shrink-0 hidden border border-gray-200 bg-white px-4 py-2 shadow-md" do
        content_tag :div, class: "flex items-center justify-between max-w-full" do
          render_bulk_selection_info(controller_name:, item_name:) +
            content_tag(:div, class: "flex items-center space-x-2") do
              safe_join(
                bulk_action_buttons.map do |button_config|
                  render_bulk_action_button(button_config:,
                                            controller_name:)
                end
              ) +
                render_bulk_delete_button(controller_name: controller_name, url: bulk_actions_url)
            end
        end
      end
    end

    private

    def render_bulk_selection_info(controller_name:, item_name:)
      content_tag :div, class: "flex items-center space-x-3" do
        content_tag(:span,
                    "0 #{item_name}(s) selected:",
                    data: { "#{controller_name}_target": "selectedCount" },
                    class: "text-sm font-medium text-gray-700") +
          content_tag(:button,
                      "Select all",
                      type: "button",
                      data: {
                        "#{controller_name}_target": "selectAllButton",
                        action: "click->#{controller_name}#selectAll"
                      },
                      class: "text-sm text-gray-600 hover:text-gray-900 hover:underline font-medium transition-colors duration-150") +
          content_tag(:button,
                      "Clear selection",
                      type: "button",
                      data: { action: "click->#{controller_name}#clearSelection" },
                      class: "text-sm text-gray-600 hover:text-gray-900 hover:underline font-medium transition-colors duration-150")
      end
    end

    def render_bulk_action_button(button_config:, controller_name:)
      label = button_config[:label] || button_config[:text] || button_config[:name]&.humanize || "Button"
      action_name = button_config[:name] || button_config[:action_name]

      data_attrs = {
        action: "click->#{controller_name}#showActionDialog",
        action_name: action_name,
        action_url: button_config[:url]&.to_s
      }

      if button_config[:action_type] == "redirect" || button_config[:action] == "redirect"
        data_attrs[:action_type] = "redirect"
      end

      if button_config[:confirm].present?
        data_attrs[:action_confirm] = button_config[:confirm]
        data_attrs[:action_label] = label
      end

      button_class = "inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 border border-input bg-background hover:bg-accent hover:text-accent-foreground h-10 px-4 py-2"
      button_class += " #{button_config[:class]}" if button_config[:class].present?

      content_tag :button,
                  label,
                  type: "button",
                  data: data_attrs,
                  class: button_class
    end

    def render_bulk_delete_button(controller_name:, url:)
      content_tag :button,
                  "Delete Selected",
                  type: "button",
                  data: {
                    action: "click->#{controller_name}#showActionDialog",
                    action_name: "delete",
                    action_label: "Delete Selected",
                    action_confirm: "Are you sure you want to delete the selected items? This action cannot be undone.",
                    action_url: url&.to_s
                  },
                  class: "inline-flex items-center justify-center rounded-md text-sm font-medium ring-offset-background transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50 border border-input bg-background hover:bg-accent hover:text-accent-foreground h-10 px-4 py-2 text-red-600 hover:text-red-700 border-red-300 hover:border-red-400"
    end
  end
end
