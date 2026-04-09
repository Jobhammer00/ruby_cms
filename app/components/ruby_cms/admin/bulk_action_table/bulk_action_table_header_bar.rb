# frozen_string_literal: true

module RubyCms
  module Admin
    module BulkActionTable
      # Header bar with optional title, filter, action icons (+ button) and search form
      # Renders using Phlex elements - no raw() needed
      #
      # @param title [String, nil] Page title (when present, filter/icons/search go on right)
      # @param header_filter [String, nil] HTML for filter content (e.g. locale links)
      # @param action_icons [Array<Hash>] Array of icon configs (url, title, color, icon, data)
      # @param search_url [String] URL for search form
      # @param search_param [String] Query param name (default: "q")
      # @param turbo_frame [String, nil] Turbo Frame ID for search/filter updates
      class BulkActionTableHeaderBar < BaseComponent
        def initialize(
          title: nil,
          header_filter: nil,
          action_icons: [],
          search_url: "#",
          search_param: "q",
          turbo_frame: nil
        )
          super
          @title = title
          @header_filter = header_filter
          @action_icons = action_icons || []
          @search_url = search_url
          @search_param = search_param
          @turbo_frame = turbo_frame
        end

        def view_template
          div(class: "px-5 py-3 border-b border-border/60 bg-white") do
            div(class: "flex items-center justify-between gap-3") do
              render_title_group if @title.present?
              div(class: "ml-auto flex items-center gap-2 overflow-x-auto whitespace-nowrap") do
                render_header_filter if @header_filter.present?
                render_action_icons
                render_search_form
              end
            end
          end
        end

        private

        def render_title_group
          div(class: "min-w-0") do
            h2(class: "text-sm font-semibold text-foreground") { @title }
          end
        end

        def render_header_filter
          raw(@header_filter) # rubocop:disable Rails/OutputSafety -- filter HTML from trusted view
        end

        def render_action_icons
          @action_icons.each {|icon_config| render_action_icon(icon_config) }
        end

        def render_action_icon(config)
          url = config[:url] || "#"
          title = config[:title]
          color = config[:color] || "blue"
          icon_path = config[:icon] || "M12 4.5v15m7.5-7.5h-15"
          data_attrs = config[:data] || {}

          color_class = icon_color_class(color)

          a(**icon_link_attrs(url, title, data_attrs, color_class)) { render_icon_svg(icon_path) }
        end

        def render_search_form
          form_options = {
            url: @search_url,
            method: :get,
            class: "w-full sm:w-auto",
            data: { "#{default_controller_name}-target": "searchForm" }
          }
          form_options[:data] = { turbo_frame: @turbo_frame } if @turbo_frame.present?
          if @turbo_frame.present?
            form_options[:data] = form_options[:data].merge(
              "#{default_controller_name}-target": "searchForm"
            )
          end

          form_with(**form_options) do
            div(class: "relative flex items-center") do
              render_search_icon
              render_search_input
            end
          end
        end

        def render_search_icon
          span(class: "absolute left-3 text-muted-foreground pointer-events-none") do
            svg(class: "h-4 w-4", fill: "none", stroke: "currentColor",
                viewBox: "0 0 24 24") do |s|
              s.path(
                stroke_linecap: "round",
                stroke_linejoin: "round",
                stroke_width: "2",
                d: "M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              )
            end
          end
        end

        def render_search_input
          input(
            type: "search",
            name: @search_param,
            placeholder: "Search",
            class: "h-9 w-64 sm:w-72 rounded-md border border-border bg-white pl-9 " \
                   "pr-3 text-sm shadow-sm focus:outline-none focus:ring-2 focus:ring-primary/20",
            value: search_value,
            data: { action: "input->#{default_controller_name}#autoSearch" }
          )
        end

        def search_value
          helpers.params[@search_param.to_sym] if helpers.respond_to?(:params)
        end

        def icon_color_class(color)
          icon_color_class_map.fetch(color.to_s, icon_color_class_map["blue"])
        end

        def icon_color_class_map
          {
            "blue" => "text-blue-600 hover:bg-blue-50",
            "green" => "text-emerald-600 hover:bg-emerald-50",
            "red" => "text-destructive hover:bg-destructive/10",
            "purple" => "text-violet-600 hover:bg-violet-50",
            "gray" => "text-muted-foreground hover:bg-muted",
            "teal" => "text-teal-600 hover:bg-teal-50"
          }
        end

        def icon_button_base_classes
          "inline-flex items-center justify-center size-9 rounded-md border border-border " \
            "bg-white shadow-sm transition-colors"
        end

        def icon_link_attrs(url, title, data_attrs, color_class)
          {
            href: url,
            class: build_classes(icon_button_base_classes, color_class),
            title: title,
            data: data_attrs
          }
        end

        def render_icon_svg(icon_path)
          svg(class: "h-4 w-4", fill: "none", stroke: "currentColor",
              viewBox: "0 0 24 24") do |s|
            s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2",
                   d: icon_path)
          end
        end

        def default_controller_name
          "ruby-cms--bulk-action-table"
        end
      end
    end
  end
end
