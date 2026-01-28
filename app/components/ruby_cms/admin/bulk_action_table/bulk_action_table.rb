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
          @header = options[:header]
          @user_attrs = extract_user_attrs(options)
          @has_bulk_actions = @bulk_actions_url.present? || @bulk_actions_buttons.any?
        end

        def extract_user_attrs(options)
          excluded_keys = %i[
            turbo_frame pagination pagination_path bulk_actions_url
            bulk_actions_buttons item_name controller_name csrf_token header
          ]
          options.reject {|key, _| excluded_keys.include?(key) }
        end

        def view_template(&block)
          if @turbo_frame
            # Use div with turbo-frame attributes as fallback
            # This ensures the content always renders
            div(id: @turbo_frame, data: { turbo_frame: @turbo_frame, turbo_action: "advance" },
                **turbo_frame_options) do
              render_table_content(&block)
            end
          else
            render_table_content(&block)
          end
        end

        def render_table_content(&block)
          div(class: "bulk-action-table", **table_data_attributes) do
            render_header if @header
            render_table_wrapper(&block)
            render_bulk_actions if @has_bulk_actions
            render_pagination if @pagination && @pagination_path
          end
        end

        def render_header
          div(class: "bulk-action-table__header-bar") do
            if @header.respond_to?(:call)
              @header.call
            elsif @header.kind_of?(String)
              raw(@header)
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
      end
    end
  end
end
