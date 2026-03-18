# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Pagination component
      # Renders pagination controls with Previous/Next and page numbers
      #
      # @param pagination [Hash] Pagination hash with current_page, total_pages, etc.
      # @param pagination_path [Proc] Lambda that generates pagination URLs
      # @param turbo_frame [String, nil] Turbo Frame ID for updates
      class BulkActionTablePagination < BaseComponent
        def initialize(
          pagination:,
          pagination_path:,
          turbo_frame: nil
        )
          super
          @pagination = pagination || {}
          @pagination_path = pagination_path
          @turbo_frame = turbo_frame
        end

        def view_template
          return unless @pagination[:total_pages] && @pagination[:total_pages] > 1

          div(class: "px-6 py-3 flex items-center justify-between gap-4") do
            render_pagination_info
            render_pagination_controls
          end
        end

        private

        def render_pagination_info
          return unless @pagination[:start_item] && @pagination[:end_item] && @pagination[:total_count]

          div(class: "text-sm text-gray-500") { pagination_info_text }
        end

        def pagination_info_text
          start_item = @pagination[:start_item]
          end_item = @pagination[:end_item]
          total_count = @pagination[:total_count]
          "Showing #{start_item}-#{end_item} of #{total_count} items"
        end

        def render_pagination_controls
          nav(class: "inline-flex items-center gap-1") do
            render_previous_button
            render_page_numbers
            render_next_button
          end
        end

        def render_previous_button
          if @pagination[:has_previous]
            render_previous_link
          else
            render_previous_disabled
          end
        end

        def render_previous_link
          link_options = {
            href: @pagination_path.call(@pagination[:previous_page]),
            class: pagination_button_classes
          }
          link_options[:data] = { turbo_frame: @turbo_frame } if @turbo_frame
          a(**link_options) { "Previous" }
        end

        def render_previous_disabled
          span(class: pagination_button_disabled_classes) { "Previous" }
        end

        def pagination_button_classes
          "inline-flex h-9 items-center justify-center rounded-md border border-gray-200 " \
            "bg-white px-3 text-sm font-medium text-gray-900 shadow-sm hover:bg-gray-50 " \
            "transition-colors"
        end

        def pagination_button_disabled_classes
          "inline-flex h-9 items-center justify-center rounded-md border border-gray-200 " \
            "bg-white px-3 text-sm font-medium text-gray-400 opacity-60 cursor-not-allowed"
        end

        def render_next_button
          if @pagination[:has_next]
            render_next_link
          else
            render_next_disabled
          end
        end

        def render_next_link
          link_options = {
            href: @pagination_path.call(@pagination[:next_page]),
            class: pagination_button_classes
          }
          link_options[:data] = { turbo_frame: @turbo_frame } if @turbo_frame
          a(**link_options) { "Next" }
        end

        def render_next_disabled
          span(class: pagination_button_disabled_classes) { "Next" }
        end

        def render_page_numbers
          current_page = @pagination[:current_page] || 1
          total_pages = @pagination[:total_pages] || 1
          pages_to_show = calculate_pages_to_show(current_page, total_pages)

          pages_to_show.each do |page_num|
            render_page_number(page_num, current_page)
          end
        end

        def render_page_number(page_num, current_page)
          if page_num == :ellipsis
            render_ellipsis
          elsif page_num == current_page
            render_current_page(page_num)
          else
            render_page_link(page_num)
          end
        end

        def render_ellipsis
          span(class: "px-2 text-sm text-gray-500") { "…" }
        end

        def render_current_page(page_num)
          span(class: current_page_classes) { page_num.to_s }
        end

        def render_page_link(page_num)
          link_options = {
            href: @pagination_path.call(page_num),
            class: pagination_button_classes
          }
          link_options[:data] = { turbo_frame: @turbo_frame } if @turbo_frame
          a(**link_options) { page_num.to_s }
        end

        def current_page_classes
          "inline-flex h-9 items-center justify-center rounded-md border border-gray-200 " \
            "bg-gray-900 px-3 text-sm font-medium text-white shadow-sm"
        end

        def calculate_pages_to_show(current_page, total_pages)
          return [1] if total_pages <= 1

          max_pages = 7
          if total_pages <= max_pages
            all_pages_array(total_pages)
          else
            complex_pages_array(current_page, total_pages)
          end
        end

        def all_pages_array(total_pages)
          (1..total_pages).to_a
        end

        def complex_pages_array(current_page, total_pages)
          pages = [1]
          start_page = calculate_start_page(current_page)
          end_page = calculate_end_page(current_page, total_pages)

          add_middle_section(pages, start_page, end_page, total_pages)
          pages << total_pages unless pages.include?(total_pages)
          pages
        end

        def calculate_start_page(current_page)
          [current_page - 1, 2].max
        end

        def calculate_end_page(current_page, total_pages)
          [current_page + 1, total_pages - 1].min
        end

        def add_middle_section(pages, start_page, end_page, total_pages)
          pages << :ellipsis if start_page > 2
          (start_page..end_page).each {|p| pages << p unless pages.include?(p) }
          pages << :ellipsis if end_page < total_pages - 1
        end
      end
    end
  end
end
