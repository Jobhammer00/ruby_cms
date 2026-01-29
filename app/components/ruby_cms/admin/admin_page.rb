# frozen_string_literal: true

module RubyCms
  module Admin
    # Admin page wrapper component
    class AdminPage < BaseComponent
      def initialize(title: nil, **options) # rubocop:disable Metrics/MethodLength
        super()
        @title = title
        @subtitle = options[:subtitle]
        @actions = options[:actions] || []
        @action_icons = options[:action_icons] || []
        @search = options[:search]
        @breadcrumbs = options[:breadcrumbs]
        @padding = options.fetch(:padding, false)
        @overflow = options.fetch(:overflow, true)
        @turbo_frame = options[:turbo_frame]
        @turbo_frame_options = options[:turbo_frame_options]
        @user_attrs = extract_user_attrs(options)
      end

      def extract_user_attrs(options)
        excluded_keys = %i[
          title subtitle actions action_icons search breadcrumbs padding overflow
          turbo_frame turbo_frame_options
        ]
        options.except(*excluded_keys)
      end

      def view_template(&)
        content = build_page_content(&)
        wrap_with_turbo_frame(content)
      end

      private

      def build_page_content(&block)
        lambda do
          div(class: "ruby_cms-admin-page", **@user_attrs) do
            render_breadcrumbs if @breadcrumbs&.any?
            render_header
            render_content(&block)
          end
        end
      end

      def wrap_with_turbo_frame(content)
        if @turbo_frame
          turbo_frame_tag(@turbo_frame, **default_turbo_frame_options, &content)
        else
          content.call
        end
      end

      def default_turbo_frame_options
        { class: "flex-1 flex flex-col min-h-0", data: { turbo_action: "advance" } }
          .merge(@turbo_frame_options || {})
      end

      def turbo_frame_tag(id, **attrs, &)
        if respond_to?(:helpers) && helpers.respond_to?(:turbo_frame_tag)
          helpers.turbo_frame_tag(id, **attrs, &)
        elsif respond_to?(:turbo_frame_tag, true)
          super
        else
          div(id: id, data: { turbo_frame: id, turbo_action: "advance" }, **attrs, &)
        end
      end

      def render_breadcrumbs
        nav(class: "ruby_cms-admin-page__breadcrumbs", aria_label: "Breadcrumb") do
          ol(class: "ruby_cms-admin-page__breadcrumb-list") do
            @breadcrumbs.each_with_index do |crumb, index|
              render_breadcrumb_item(crumb, index == @breadcrumbs.size - 1)
            end
          end
        end
      end

      def render_breadcrumb_item(crumb, last)
        li(class: "ruby_cms-admin-page__breadcrumb-item") do
          last ? render_breadcrumb_current(crumb) : render_breadcrumb_link(crumb)
        end
      end

      def render_breadcrumb_current(crumb)
        span(class: "ruby_cms-admin-page__breadcrumb-current", aria_current: "page") do
          crumb[:label] || crumb[:text]
        end
      end

      def render_breadcrumb_link(crumb)
        a(href: crumb[:url] || crumb[:path], class: "ruby_cms-admin-page__breadcrumb-link") do
          crumb[:label] || crumb[:text]
        end
      end

      def render_header
        return unless @title || @action_icons.any? || @actions.any? || @search

        div(class: "ruby_cms-page-header") do
          div(class: "ruby_cms-page-header__content") do
            render_header_title_group
            render_header_actions_icons
          end
          render_search if @search
          render_header_action_buttons
        end
      end

      def render_header_title_group
        return unless @title || @subtitle

        div(class: "ruby_cms-page-header__title-group") do
          h1(class: "ruby_cms-page-title") { @title } if @title
          p(class: "ruby_cms-page-subtitle") { @subtitle } if @subtitle
        end
      end

      def render_header_actions_icons
        return unless @action_icons.any?

        div(class: "ruby_cms-page-header__action-icons") do
          @action_icons.each {|icon_action| render_icon_action(icon_action) }
        end
      end

      def render_header_action_buttons
        @actions.each {|action| render_action_button(action) }
      end

      def render_icon_action(action)
        if get_method?(action[:method])
          render_icon_link(action)
        else
          render_icon_form(action)
        end
      end

      def render_icon_link(action)
        a(href: action_url(action), **icon_attrs(action)) { render_icon(action[:icon]) }
      end

      def render_icon_form(action)
        form_with(url: action_url(action), method: action[:method],
                  class: "ruby_cms-inline-form") do
          button(type: "submit", **icon_attrs(action)) { render_icon(action[:icon]) }
        end
      end

      def icon_attrs(action)
        attrs = {
          class: "ruby_cms-page-header__icon-action \
            ruby_cms-page-header__icon-action--#{action[:color] || 'blue'}",
          title: action[:title] || action[:label] || "",
          aria_label: action[:title] || action[:label] || ""
        }
        attrs[:data] = action[:data] if action[:data]
        attrs
      end

      def action_url(action)
        action[:url] || action[:path] || "#"
      end

      def render_icon(icon)
        case icon
        when String then svg_icon_path(icon)
        when Hash then svg_icon_hash(icon)
        else sanitize(
          icon.to_s,
          tags: %w[svg path g circle rect line polygon polyline ellipse text],
          attributes: %w[
            fill stroke stroke-linecap stroke-linejoin stroke-width d
            class viewBox cx cy r x y points x1 y1 x2 y2 aria-current id title aria-label
          ]
        )
        end
      end

      def svg_icon_path(path)
        svg(class: "ruby_cms-page-header__icon", fill: "none", stroke: "currentColor",
            viewBox: "0 0 24 24") do |s|
          s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: path)
        end
      end

      def svg_icon_hash(icon)
        svg(class: "ruby_cms-page-header__icon",
            fill: icon[:fill] || "none",
            stroke: icon[:stroke] || "currentColor",
            viewBox: icon[:viewBox] || "0 0 24 24") do |s|
          Array(icon[:paths] || icon[:path]).compact.each {|p| s.path(**p) }
        end
      end

      def render_action_button(action)
        if action[:html].present?
          render_safe_html_action(action)
        else
          render_standard_action(action)
        end
      end

      def render_safe_html_action(action)
        content = action[:html].to_s
        sanitize(content)
      end

      def render_standard_action(action)
        label = action[:label] || action[:text] || action[:name]&.humanize || "Action"
        render_action_element(action_url(action), action[:method] || :get,
                              build_action_attributes(action), label)
      end

      def build_action_attributes(action)
        class_name = "ruby_cms-btn"
        class_name += " #{action[:class]}" if action[:class]
        class_name += " ruby_cms-btn-primary" if action_primary?(action)
        class_name += " ruby_cms-btn-secondary" if action_secondary?(action)
        attrs = { class: class_name }
        attrs[:data] = action[:data] if action[:data]
        attrs
      end

      def action_primary?(action)
        action[:primary] != false && action[:style] != "secondary"
      end

      def action_secondary?(action)
        action[:style] == "secondary" || action[:primary] == false
      end

      def render_action_element(url, method, attrs, label)
        if get_method?(method)
          a(href: url, **attrs) do
            label
          end
        else
          render_form_action(url, method, attrs, label)
        end
      end

      def render_form_action(url, method, attrs, label)
        form_with(url: url, method: method, class: "ruby_cms-inline-form") do
          button(type: "submit", **attrs) { label }
        end
      end

      def render_content(&)
        div(class: "ruby_cms-admin-page__content") { yield if block_given? }
      end

      def render_search
        opts = @search.kind_of?(Hash) ? @search : { placeholder: "Search" }
        form_with(url: opts[:url] || "#", method: :get, class: "ruby_cms-page-header__search-form",
                  data: { turbo_frame: opts[:turbo_frame] || "admin_table_content" }) do
          div(class: "ruby_cms-page-header__search-wrapper") do
            svg_icon_path("M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z")
            input(
              type: "search", name: opts[:name] || "q", placeholder: opts[:placeholder] || "Search",
              class: "ruby_cms-page-header__search-input", value: opts[:value],
              data: { action: "input->turbo-frame#submit" }
            )
          end
        end
      end

      def get_method?(method)
        [:get, "get"].include?(method)
      end
    end
  end
end
