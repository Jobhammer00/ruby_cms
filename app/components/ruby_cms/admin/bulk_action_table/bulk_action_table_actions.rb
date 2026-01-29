# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Row action buttons component
      # Renders Edit and Delete buttons for each table row
      #
      # @param edit_path [String, nil] URL to edit page
      # @param delete_path [String, nil] URL to delete action
      # @param delete_confirm [String] Confirmation message for delete
      # @param require_confirm [Boolean] Whether to require confirmation (default: true)
      # @param turbo_frame [String, nil] Turbo Frame ID for updates
      # @param controller_name [String] Stimulus controller identifier
      class BulkActionTableActions < BaseComponent
        def initialize( # rubocop:disable Metrics/ParameterLists
          delete_path:,
          item_id:,
          edit_path: nil,
          delete_confirm: "Are you sure you want to delete this item?",
          require_confirm: true,
          turbo_frame: nil,
          controller_name: "ruby-cms--bulk-action-table"
        )
          super
          @edit_path = edit_path
          @delete_path = delete_path
          @item_id = item_id
          @delete_confirm = delete_confirm
          @require_confirm = require_confirm
          @turbo_frame = turbo_frame
          @controller_name = controller_name
        end

        def view_template
          div(class: "bulk-action-table__actions") do
            render_edit_button if @edit_path

            render_delete_button if @delete_path
          end
        end

        private

        def render_edit_button
          link_options = {
            href: @edit_path,
            class: "bulk-action-table__action-button bulk-action-table__action-button--edit"
          }
          link_options[:data] = { turbo_frame: @turbo_frame } if @turbo_frame

          a(**link_options) do
            svg(
              xmlns: "http://www.w3.org/2000/svg",
              viewBox: "0 0 20 20",
              fill: "currentColor",
              class: "bulk-action-table__action-icon"
            ) do |s|
              s.path(
                d: edit_icon_path_d
              )
              s.path(
                d: edit_icon_path_d2
              )
            end
          end
        end

        def render_delete_button
          item_id = @item_id || extract_item_id_from_path
          button(
            type: "button",
            class: "bulk-action-table__action-button bulk-action-table__action-button--delete",
            data: {
              action: "click->#{@controller_name}#showIndividualDeleteDialog",
              "#{@controller_name}-item-id-param": item_id,
              delete_path: @delete_path,
              require_confirm: @require_confirm
            }
          ) do
            svg(
              xmlns: "http://www.w3.org/2000/svg",
              viewBox: "0 0 20 20",
              fill: "currentColor",
              class: "bulk-action-table__action-icon"
            ) do |s|
              s.path(
                fill_rule: "evenodd",
                d: delete_icon_path_d,
                clip_rule: "evenodd"
              )
            end
          end
        end

        def edit_icon_path_d
          "M5.433 13.917l1.262-3.155A4 4 0 017.58 9.42l6.92-6.918a2.121 2.121 0 013 3" \
            "l-6.92 6.918c-.383.383-.84.685-1.343.886l-3.154 1.262a.5.5 0 01-.65-.65z"
        end

        def edit_icon_path_d2
          "M3.5 5.75c0-.69.56-1.25 1.25-1.25H10A.75.75 0 0010 3H4.75A2.75 2.75 0 002 5.75" \
            "v9.5A2.75 2.75 0 004.75 18h9.5A2.75 2.75 0 0017 15.25V10a.75.75 0 00-1.5 0" \
            "v5.25c0 .69-.56 1.25-1.25 1.25h-9.5c-.69 0-1.25-.56-1.25-1.25v-9.5z"
        end

        def delete_icon_path_d
          "M8.75 1A2.75 2.75 0 006 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 10" \
            ".23 1.482l.149-.022.841 10.518A2.75 2.75 0 007.596 19h4.807a2.75 2.75 0 00" \
            "2.742-2.53l.841-10.52.149.023a.75.75 0 00.23-1.482A41.03 41.03 0 0014 4.193" \
            "V3.75A2.75 2.75 0 0011.25 1h-2.5zM10 4c.84 0 1.673.025 2.5.075V3.75c0-.69" \
            "-.56-1.25-1.25-1.25h-2.5c-.69 0-1.25.56-1.25 1.25v.325C8.327 4.025 9.16 4 " \
            "10 4zM8.58 7.72a.75.75 0 00-1.5.06l.3 7.5a.75.75 0 101.5-.06l-.3-7.5zm4.34" \
            ".06a.75.75 0 10-1.5-.06l-.3 7.5a.75.75 0 101.5.06l.3-7.5z"
        end

        def extract_item_id_from_path
          # Try to extract item ID from delete_path (e.g., "/admin/users/123" -> "123")
          # This is a fallback - ideally item_id should be passed explicitly
          @delete_path.to_s.split("/").last
        end
      end
    end
  end
end
