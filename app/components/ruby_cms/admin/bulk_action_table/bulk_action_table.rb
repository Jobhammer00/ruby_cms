# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Root component for bulk action table
      # Wraps entire table with Turbo Frame support, pagination, and bulk actions bar
      #
      # @param turbo_frame [String, nil] Turbo Frame ID (e.g., "admin_table_content")
      # @param pagination [Hash, nil] Pagination hash with current_page, total_pages, etc.
      # @param pagination_path [Proc, nil] Lambda that generates pagination URLs
      # @param bulk_actions_url [String, nil] URL for bulk delete action
      # @param bulk_actions_buttons [Array<Hash>] Array of custom bulk action button configs
      # @param item_name [String] Singular name for items (e.g., "error", "schedule")
      # @param controller_name [String] Stimulus controller identifier
      #   (default: "ruby-cms--bulk-action-table")
      class BulkActionTable < BaseComponent
        def initialize(**options)
          super()
          @turbo_frame = options[:turbo_frame]
          @pagination = options[:pagination]
          @pagination_path = options[:pagination_path]
          @bulk_actions_url = options[:bulk_actions_url]
          @bulk_actions_buttons = options[:bulk_actions_buttons] || []
          @item_name = options.fetch(:item_name, "item")
          @controller_name = options.fetch(:controller_name, "ruby-cms--bulk-action-table")
          @csrf_token = options[:csrf_token]
          @user_attrs = extract_user_attrs(options)
          @has_bulk_actions = @bulk_actions_url.present? || @bulk_actions_buttons.any?
        end

        def extract_user_attrs(options)
          excluded_keys = %i[
            turbo_frame pagination pagination_path bulk_actions_url
            bulk_actions_buttons item_name controller_name csrf_token
          ]
          options.reject { |key, _| excluded_keys.include?(key) }
        end

        def view_template(&)
          content = build_table_content(&)
          wrap_with_turbo_frame(content)
        end

        def build_table_content(&)
          lambda do
            div(class: "bulk-action-table", **table_data_attributes) do
              render_table_wrapper(&)
              render_bulk_actions if @has_bulk_actions
              render_pagination if @pagination && @pagination_path
            end
          end
        end

        def render_table_wrapper(&)
          div(class: "bulk-action-table__wrapper") do
            div(class: "bulk-action-table__scroll-container") do
              div(class: "bulk-action-table__table-container") do
                table(class: "bulk-action-table__table") do
                  yield if block_given?
                end
              end
            end
          end
        end

        def render_bulk_actions
          render BulkActions.new(
            controller_name: @controller_name,
            item_name: @item_name,
            bulk_actions_url: @bulk_actions_url,
            bulk_action_buttons: @bulk_actions_buttons
          )
          render BulkActionTableDeleteModal.new(controller_name: @controller_name)
        end

        def render_pagination
          render BulkActionTablePagination.new(
            pagination: @pagination,
            pagination_path: @pagination_path,
            turbo_frame: @turbo_frame
          )
        end

        def wrap_with_turbo_frame(content)
          if @turbo_frame
            turbo_frame_tag(@turbo_frame, **turbo_frame_options, &content)
          else
            content.call
          end
        end

        private

        def table_data_attributes
          csrf_token = @csrf_token || form_authenticity_token
          attrs = {
            data: {
              controller: @controller_name,
              "#{@controller_name}-csrf-token-value": csrf_token,
              "#{@controller_name}-item-name-value": @item_name
            }
          }

          if @bulk_actions_url.present?
            attrs[:data]["#{@controller_name}-bulk-action-url-value"] = @bulk_actions_url
          end

          attrs.merge(@user_attrs)
        end

        def turbo_frame_options
          {
            class: "flex-1 flex flex-col min-h-0",
            data: { turbo_action: "advance" }
          }
        end

        def turbo_frame_tag(id, **, &)
          if respond_to?(:helpers) && helpers.respond_to?(:turbo_frame_tag)
            helpers.turbo_frame_tag(id, **, &)
          elsif respond_to?(:turbo_frame_tag, true)
            super
          else
            # Fallback: render as div with data-turbo-frame attribute
            div(id: id, data: { turbo_frame: id, turbo_action: "advance" }, **, &)
          end
        end
      end
    end
  end
end
