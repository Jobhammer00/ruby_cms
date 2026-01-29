# frozen_string_literal: true

module RubyCms
  module BulkActionTableHelper
    # Render the bulk action table delete dialog
    # @param controller_name [String] The Stimulus controller name
    # @return [String] Rendered HTML for the delete dialog
    def render_bulk_action_table_delete_dialog(controller_name: "ruby-cms--bulk-action-table")
      render partial: "ruby_cms/admin/shared/bulk_action_table_delete_dialog",
             locals: { controller_name: }
    end

    # Render bulk actions bar
    # @param controller_name [String]
    # @param item_name [String]
    # @param bulk_actions_url [String]
    # @param bulk_action_buttons [Array<Hash>]
    def render_bulk_actions_bar(
      controller_name: "ruby-cms--bulk-action-table",
      item_name: "item",
      bulk_actions_url: nil,
      bulk_action_buttons: []
    )
      content_tag :div,
                  data: { "#{controller_name}_target": "bulkBar" },
                  class: "flex-shrink-0 hidden border border-gray-200
                    bg-white px-4 py-2 shadow-md" do
        content_tag :div, class: "flex items-center justify-between max-w-full" do
          render_bulk_selection_info(controller_name:, item_name:) +
            render_bulk_action_buttons(controller_name:, bulk_action_buttons:, bulk_actions_url:)
        end
      end
    end

    private

    def render_bulk_selection_info(controller_name:, item_name:)
      content_tag :div, class: "flex items-center space-x-3" do
        selected_count_span(controller_name:, item_name:) +
          select_all_button(controller_name:) +
          clear_selection_button
      end
    end

    def selected_count_span(controller_name:, item_name:)
      content_tag(:span,
                  "0 #{item_name}(s) selected:",
                  data: { "#{controller_name}_target": "selectedCount" },
                  class: "text-sm font-medium text-gray-700")
    end

    def select_all_button(controller_name:)
      content_tag(:button,
                  "Select all",
                  type: "button",
                  data: {
                    "#{controller_name}_target": "selectAllButton",
                    action: "click->#{controller_name}#selectAll"
                  },
                  class: "text-sm
                    text-gray-600
                    hover:text-gray-900
                    hover:underline
                    font-medium
                    transition-colors
                    duration-150")
    end

    def clear_selection_button
      content_tag(:button,
                  "Clear selection",
                  type: "button",
                  data: { action: "click->ruby-cms--bulk-action-table#clearSelection" },
                  class: "text-sm
                    text-gray-600
                    hover:text-gray-900
                    hover:underline
                    font-medium
                    transition-colors
                    duration-150")
    end

    def render_bulk_action_buttons(controller_name:, bulk_action_buttons:, bulk_actions_url:)
      content_tag(:div, class: "flex items-center space-x-2") do
        safe_join(
          bulk_action_buttons.map {|cfg| render_bulk_action_button(cfg, controller_name) } +
            [render_bulk_delete_button(controller_name: controller_name, url: bulk_actions_url)]
        )
      end
    end

    def render_bulk_action_button(button_config, controller_name)
      label = button_label(button_config)
      data_attrs = build_button_data_attrs(button_config, controller_name, label)
      button_class = build_button_class(button_config)

      content_tag(:button, label, type: "button", data: data_attrs, class: button_class)
    end

    def button_label(cfg)
      cfg[:label] || cfg[:text] || cfg[:name]&.humanize || "Button"
    end

    def build_button_data_attrs(cfg, controller_name, label)
      attrs = {
        action: "click->#{controller_name}#showActionDialog",
        action_name: cfg[:name] || cfg[:action_name],
        action_url: cfg[:url]&.to_s
      }
      if %w[redirect].include?(cfg[:action_type]) || cfg[:action] == "redirect"
        attrs[:action_type] =
          "redirect"
      end
      if cfg[:confirm].present?
        attrs[:action_confirm] = cfg[:confirm]
        attrs[:action_label] = label
      end
      attrs
    end

    def build_button_class(cfg)
      base = "inline-flex
      items-center justify-center rounded-md text-sm
      font-medium ring-offset-background transition-colors
      focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring
      focus-visible:ring-offset-2 disabled:pointer-events-none disabled:opacity-50
      border border-input bg-background hover:bg-accent hover:text-accent-foreground h-10 px-4 py-2"
      cfg[:class].present? ? "#{base} #{cfg[:class]}" : base
    end

    def render_bulk_delete_button(controller_name:, url:)
      content_tag(:button,
                  "Delete Selected",
                  type: "button",
                  data: {
                    action: "click->#{controller_name}#showActionDialog",
                    action_name: "delete",
                    action_label: "Delete Selected",
                    action_confirm: "Are you sure you want to delete the selected items?
                    This action cannot be undone.",
                    action_url: url&.to_s
                  },
                  class: "inline-flex items-center justify-center rounded-md text-sm
                    font-medium ring-offset-background transition-colors focus-visible:outline-none
                    focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2
                    disabled:pointer-events-none disabled:opacity-50 border border-input
                    bg-background hover:bg-accent hover:text-accent-foreground h-10 px-4 py-2
                    text-red-600 hover:text-red-700 border-red-300 hover:border-red-400")
    end
  end
end
