# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTableHelper
      # Render a complete bulk action table using Phlex components
      #
      # @param collection [ActiveRecord::Relation] The collection to display
      # @param headers [Array<String, Hash>] Array of header labels or hashes with :text and :class
      # @param turbo_frame [String, nil] Turbo Frame ID for seamless updates
      # @param pagination [Hash, nil] Pagination hash from AdminPagination concern
      # @param pagination_path [Proc, nil] Lambda for generating pagination URLs
      # @param bulk_actions_url [String, nil] URL for bulk delete action
      # @param bulk_action_buttons [Array<Hash>] Array of custom bulk action button configs
      # @param item_name [String] Singular name for items (default: "item")
      # @param controller_name [String] Stimulus controller identifier
      # @param block [Proc] Block that renders table rows
      # @return [String] Rendered HTML
      #
      # @example Basic usage
      #   <%= render_bulk_action_table(
      #     collection: @items,
      #     headers: ["Name", "Status", { text: "Actions", class: "text-right" }],
      #     bulk_actions_url: bulk_delete_items_path,
      #     item_name: "item"
      #   ) do %>
      #     <% @items.each do |item| %>
      #       <%= render RubyCms::Admin::BulkActionTable::BulkActionTableRow.new(
      #         data: { item_id: item.id }
      #       ) do %>
      #         <td><%= item.name %></td>
      #         <td><%= item.status %></td>
      #         <td class="text-right">
      #           <%= render RubyCms::Admin::BulkActionTable::BulkActionTableActions.new(
      #             edit_path: edit_item_path(item),
      #             delete_path: item_path(item),
      #             item_id: item.id
      #           ) %>
      #         </td>
      #       <% end %>
      #     <% end %>
      #   <% end %>
      def render_bulk_action_table(
        headers:,
        turbo_frame: "admin_table_content",
        pagination: nil,
        pagination_path: nil,
        bulk_actions_url: nil,
        bulk_action_buttons: [],
        item_name: "item",
        controller_name: "ruby-cms--bulk-action-table",
        &block
      )
        render RubyCms::Admin::BulkActionTable::BulkActionTable.new(
          turbo_frame: turbo_frame,
          pagination: pagination,
          pagination_path: pagination_path,
          bulk_actions_url: bulk_actions_url,
          bulk_actions_buttons: bulk_action_buttons,
          item_name: item_name,
          controller_name: controller_name,
          csrf_token: form_authenticity_token
        ) do
          render RubyCms::Admin::BulkActionTable::BulkActionTableHeader.new(
            headers: headers,
            bulk_actions_enabled: bulk_actions_url.present? || bulk_action_buttons.any?,
            controller_name: controller_name
          )

          render RubyCms::Admin::BulkActionTable::BulkActionTableBody.new(&block)
        end
      end

      # Render an admin page with consistent layout
      #
      # @param title [String] Page title
      # @param subtitle [String, nil] Optional subtitle
      # @param actions [Array<Hash>, nil] Array of action button configs
      # @param breadcrumbs [Array<Hash>, nil] Array of breadcrumb items
      # @param padding [Boolean] Add padding classes (default: true)
      # @param overflow [Boolean] Allow overflow (default: true)
      # @param turbo_frame [String, nil] Turbo Frame ID for wrapping
      # @param turbo_frame_options [Hash, nil] Custom Turbo Frame options
      # @param block [Proc] Block that renders page content
      # @return [String] Rendered HTML
      #
      # @example
      #   <%= render_admin_page(
      #     title: "Content Blocks",
      #     actions: [
      #       { label: "New Block", url: new_content_block_path, primary: true }
      #     ],
      #     turbo_frame: "admin_table_content"
      #   ) do %>
      #     <div class="ruby_cms-card">
      #       <!-- Content here -->
      #     </div>
      #   <% end %>
      def render_admin_page(
        title:,
        subtitle: nil,
        actions: nil,
        breadcrumbs: nil,
        padding: true,
        overflow: true,
        turbo_frame: nil,
        turbo_frame_options: nil
      )
        render RubyCms::Admin::AdminPage.new(
          title:,
          subtitle:,
          actions:,
          breadcrumbs:,
          padding:,
          overflow:,
          turbo_frame:,
          turbo_frame_options:
        ) do
          yield if block_given?
        end
      end

      # Build bulk action button configuration hash
      #
      # @param name [String] Action name (used internally)
      # @param label [String] Button label text
      # @param url [String] Action URL
      # @param confirm [String, nil] Confirmation message
      # @param action_type [String] "redirect" for redirect actions, nil for dialog actions
      # @param class [String, nil] Additional CSS classes
      # @return [Hash] Button configuration hash
      #
      # @example
      #   bulk_action_button(
      #     name: "publish",
      #     label: "Publish Selected",
      #     url: bulk_publish_path,
      #     confirm: "Are you sure?"
      #   )
      def bulk_action_button(
        name:,
        label:,
        url:,
        confirm: nil,
        action_type: nil,
        class: nil
      )
        {
          name: name,
          label: label,
          url: url,
          confirm: confirm,
          action_type: action_type,
          class: binding.local_variable_get(:class)
        }.compact
      end
    end
  end
end
