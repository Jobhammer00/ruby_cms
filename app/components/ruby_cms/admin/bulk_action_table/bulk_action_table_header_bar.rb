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
        def initialize( # rubocop:disable Metrics/ParameterLists
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
          div(class: "bulk-action-table__header-bar") do
            div(class: "ruby_cms-page-header__content") do
              render_title_group if @title.present?
              div(class: "ruby_cms-page-header__action-icons") do
                render_header_filter if @header_filter.present?
                render_action_icons
                render_search_form
              end
            end
          end
        end

        private

        def render_title_group
          div(class: "ruby_cms-page-header__title-group") do
            h1(class: "ruby_cms-page-title") { @title }
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

          a(
            href: url,
            class: "ruby_cms-page-header__icon-action ruby_cms-page-header__icon-action--#{color}",
            title: title,
            data: data_attrs
          ) do
            svg(class: "ruby_cms-page-header__icon", fill: "none", stroke: "currentColor",
                viewBox: "0 0 24 24") do |s|
              s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2",
                     d: icon_path)
            end
          end
        end

        def render_search_form
          form_options = {
            url: @search_url,
            method: :get,
            class: "ruby_cms-page-header__search-form"
          }
          form_options[:data] = { turbo_frame: @turbo_frame } if @turbo_frame.present?

          form_with(**form_options) do
            div(class: "ruby_cms-page-header__search-wrapper") do
              render_search_icon
              render_search_input
            end
          end
        end

        def render_search_icon
          svg(class: "ruby_cms-page-header__search-icon", fill: "none", stroke: "currentColor",
              viewBox: "0 0 24 24") do |s|
            s.path(
              stroke_linecap: "round",
              stroke_linejoin: "round",
              stroke_width: "2",
              d: "M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            )
          end
        end

        def render_search_input
          input(
            type: "search",
            name: @search_param,
            placeholder: "Search",
            class: "ruby_cms-page-header__search-input",
            value: search_value,
            data: { action: "input->turbo-frame#submit" }
          )
        end

        def search_value
          helpers.params[@search_param.to_sym] if helpers.respond_to?(:params)
        end
      end
    end
  end
end
