# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Delete confirmation modal component
      # Shows confirmation dialog for bulk delete actions
      #
      # @param controller_name [String] Stimulus controller identifier
      class BulkActionTableDeleteModal < BaseComponent
        def initialize(controller_name: "ruby-cms--bulk-action-table")
          super
          @controller_name = controller_name
        end

        def view_template
          div(**dialog_overlay_attributes) do
            render_backdrop
            render_dialog_container
          end
        end

        private

        def dialog_overlay_attributes
          {
            class: "fixed inset-0 z-50 hidden",
            data: {
              "#{@controller_name}-target": "dialogOverlay",
              action: "keydown->#{@controller_name}#handleKeydown"
            },
            role: "dialog",
            aria_modal: "true",
            aria_labelledby: "dialog-title"
          }
        end

        def render_backdrop
          div(
            class: "absolute inset-0 bg-black/50",
            data: {
              action: "click->#{@controller_name}#closeDialog"
            }
          )
        end

        def render_dialog_container
          div(class: "relative flex min-h-full items-center justify-center p-4") do
            div(**dialog_content_attributes) do
              render_header_with_close
              render_message
              render_footer
            end
          end
        end

        def render_header_with_close
          div(class: "flex items-start justify-between gap-4") do
            render_header
            render_close_button
          end
        end

        def dialog_content_attributes
          {
            class: "w-full max-w-md rounded-xl border border-border/60 bg-white p-6 shadow-lg ring-1 ring-black/[0.03]",
            data: {
              "#{@controller_name}-target": "dialogContent"
            },
            tabindex: "-1"
          }
        end

        def render_close_button
          button(
            type: "button",
            class: "inline-flex size-8 items-center justify-center rounded-md text-muted-foreground " \
                   "hover:bg-muted hover:text-foreground transition-colors",
            data: {
              action: "click->#{@controller_name}#closeDialog"
            },
            aria_label: t("ruby_cms.admin.bulk_action_table.close", default: "Close")
          ) do
            render_close_icon
            span(class: "sr-only") { t("ruby_cms.admin.bulk_action_table.close", default: "Close") }
          end
        end

        def render_close_icon
          svg(
            width: "15",
            height: "15",
            viewBox: "0 0 15 15",
            fill: "none",
            xmlns: "http://www.w3.org/2000/svg",
            class: "h-4 w-4"
          ) do |s|
            s.path(
              d: close_icon_path_d,
              fill: "currentColor",
              fill_rule: "evenodd",
              clip_rule: "evenodd"
            )
          end
        end

        def close_icon_path_d
          "M11.7816 4.03157C12.0062 3.80702 12.0062 3.44295 11.7816 3.2184C11.5571 " \
            "2.99385 11.193 2.99385 10.9685 3.2184L7.50005 6.68682L4.03164 " \
            "3.2184C3.80708 2.99385 3.44301 2.99385 3.21846 3.2184C2.99391 " \
            "3.44295 2.99391 3.80702 3.21846 4.03157L6.68688 7.49999L3.21846 " \
            "10.9684C2.99391 11.193 2.99391 11.557 3.21846 11.7816C3.44301 " \
            "12.0061 3.80708 12.0061 4.03164 11.7816L7.50005 8.31316L10.9685 " \
            "11.7816C11.193 12.0061 11.5571 12.0061 11.7816 11.7816C12.0062 " \
            "11.557 12.0062 11.193 11.7816 10.9684L8.31322 7.49999L11.7816 " \
            "4.03157Z"
        end

        def render_header
          h3(
            id: "dialog-title",
            class: "text-base font-semibold text-foreground",
            data: {
              "#{@controller_name}-target": "dialogTitle"
            }
          ) { t("ruby_cms.admin.bulk_action_table.delete_selected_items", default: "Delete Selected Items") }
        end

        def render_message
          div(
            class: "mt-3 text-sm text-muted-foreground space-y-1",
            data: {
              "#{@controller_name}-target": "dialogMessage"
            }
          ) do
            p { t("ruby_cms.admin.bulk_action_table.are_you_sure_you_want_to_delete_the_selected_items", default: "Are you sure you want to delete the selected items?") }
            p { t("ruby_cms.admin.bulk_action_table.this_action_cannot_be_undone", default: "This action cannot be undone.") }
          end
        end

        def render_footer
          div(class: "mt-6 flex items-center justify-end gap-2") do
            render_cancel_button
            render_confirm_button
          end
        end

        def render_cancel_button
          button(
            type: "button",
            class: "inline-flex h-9 items-center justify-center rounded-md border " \
                   "border-border bg-white px-4 text-sm font-medium text-foreground " \
                   "shadow-sm hover:bg-muted transition-colors",
            data: {
              action: "click->#{@controller_name}#closeDialog"
            }
          ) { t("ruby_cms.admin.bulk_action_table.cancel", default: "Cancel") }
        end

        def render_confirm_button
          button(
            type: "button",
            class: "inline-flex h-9 items-center justify-center rounded-md bg-destructive px-4 " \
                   "text-sm font-medium text-white font-bold shadow-sm hover:bg-destructive/90 transition-colors",
            data: {
              "#{@controller_name}-target": "dialogConfirmButton",
              action: "click->#{@controller_name}#confirmAction"
            }
          ) { t("ruby_cms.admin.bulk_action_table.delete_selected", default: "Delete Selected") }
        end
      end
    end
  end
end
