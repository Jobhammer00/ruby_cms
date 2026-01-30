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
            class: "bulk-action-dialog hidden",
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
            class: "bulk-action-dialog__backdrop",
            data: {
              action: "click->#{@controller_name}#closeDialog"
            }
          )
        end

        def render_dialog_container
          div(class: "bulk-action-dialog__container") do
            div(**dialog_content_attributes) do
              render_header_with_close
              render_message
              render_footer
            end
          end
        end

        def render_header_with_close
          div(class: "bulk-action-dialog__header-row") do
            render_header
            render_close_button
          end
        end

        def dialog_content_attributes
          {
            class: "bulk-action-dialog__content",
            data: {
              "#{@controller_name}-target": "dialogContent"
            },
            tabindex: "-1"
          }
        end

        def render_close_button
          button(
            type: "button",
            class: "bulk-action-dialog__close",
            data: {
              action: "click->#{@controller_name}#closeDialog"
            },
            aria_label: "Close"
          ) do
            render_close_icon
            span(class: "sr-only") { "Close" }
          end
        end

        def render_close_icon
          svg(
            width: "15",
            height: "15",
            viewBox: "0 0 15 15",
            fill: "none",
            xmlns: "http://www.w3.org/2000/svg",
            class: "bulk-action-dialog__close-icon"
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
            class: "bulk-action-dialog__title",
            data: {
              "#{@controller_name}-target": "dialogTitle"
            }
          ) { "Delete Selected Items" }
        end

        def render_message
          div(
            class: "bulk-action-dialog__message",
            data: {
              "#{@controller_name}-target": "dialogMessage"
            }
          ) do
            p { "Are you sure you want to delete the selected items?" }
            p { "This action cannot be undone." }
          end
        end

        def render_footer
          div(class: "bulk-action-dialog__footer") do
            render_cancel_button
            render_confirm_button
          end
        end

        def render_cancel_button
          button(
            type: "button",
            class: "bulk-action-dialog__button",
            data: {
              action: "click->#{@controller_name}#closeDialog"
            }
          ) { "Cancel" }
        end

        def render_confirm_button
          button(
            type: "button",
            class: "bulk-action-dialog__button bulk-action-dialog__button--confirm",
            data: {
              "#{@controller_name}-target": "dialogConfirmButton",
              action: "click->#{@controller_name}#confirmAction"
            }
          ) { "Delete Selected" }
        end
      end
    end
  end
end
