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
            span(class: "text-sm font-medium text-foreground") do
              t("ruby_cms.admin.bulk_action_table.selected", default: "selected")
            end
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
          ) { t("ruby_cms.admin.bulk_action_table.select_all", default: "Select all") }

          button(
            type: "button",
            class: "text-xs font-medium text-muted-foreground hover:text-foreground transition-colors",
            data: {
              action: "click->#{@controller_name}#clearSelection"
            }
          ) { t("ruby_cms.admin.bulk_action_table.clear", default: "Clear") }
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
          icon_path = resolve_icon_path(config, action_name)

          button(
            type: "button",
            class: build_button_class(config),
            data: build_button_data_attrs(config, label, action_name)
          ) do
            render_button_icon(icon_path)
            span { label }
          end
        end

        def build_button_class(config)
          color_class = resolve_button_color_class(config)
          base = "inline-flex items-center justify-center gap-1.5 rounded-md border border-border " \
                 "bg-white px-3 py-1.5 text-sm font-medium shadow-sm " \
                 "hover:bg-muted transition-colors"
          [base, color_class, config[:class]].compact.join(" ")
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
            class: "inline-flex items-center justify-center gap-1.5 rounded-md border border-destructive/30 " \
                   "bg-white px-3 py-1.5 text-sm font-medium text-destructive shadow-sm " \
                   "hover:bg-destructive/10 transition-colors",
            data: {
              action: "click->#{@controller_name}#showActionDialog",
              action_name: "delete",
              action_label: t("ruby_cms.admin.bulk_action_table.delete_selected", default: "Delete Selected"),
              action_confirm: t("ruby_cms.admin.bulk_action_table.delete_selected_confirm", default: "Are you sure you want to delete the selected items? This action cannot be undone."),
              action_url: @bulk_actions_url&.to_s
            }
          ) do
            render_button_icon("M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16")
            span { t("ruby_cms.admin.bulk_action_table.delete_selected", default: "Delete Selected") }
          end
        end

        def render_button_icon(path_d)
          svg(class: "h-3.5 w-3.5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do |s|
            s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: path_d)
          end
        end

        def resolve_button_color_class(config)
          color = (config[:color] || config[:tone] || config[:variant]).to_s
          return "text-foreground" if color.blank?

          {
            "blue" => "text-blue-700 border-blue-200 hover:bg-blue-50",
            "green" => "text-emerald-700 border-emerald-200 hover:bg-emerald-50",
            "emerald" => "text-emerald-700 border-emerald-200 hover:bg-emerald-50",
            "orange" => "text-amber-700 border-amber-200 hover:bg-amber-50",
            "amber" => "text-amber-700 border-amber-200 hover:bg-amber-50",
            "red" => "text-destructive border-destructive/30 hover:bg-destructive/10",
            "purple" => "text-violet-700 border-violet-200 hover:bg-violet-50"
          }.fetch(color, "text-foreground")
        end

        def resolve_icon_path(config, action_name)
          return config[:icon] if config[:icon].present?

          case action_name.to_s
          when "publish"
            "M5 13l4 4L19 7"
          when "unpublish"
            "M6 18L18 6M6 6l12 12"
          when "archive"
            "M20 7l-1 12H5L4 7m16 0H4m3-3h10l1 3H6l1-3z"
          else
            "M12 4v16m8-8H4"
          end
        end
      end
    end
  end
end
