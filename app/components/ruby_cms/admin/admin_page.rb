# frozen_string_literal: true

module RubyCms
  module Admin
    # Admin page wrapper component (Tailwind-first)
    #
    # NOTE: This file must exist (at this path) so Zeitwerk autoloads
    # `RubyCms::Admin::AdminPage` as a CLASS (not a module inferred from the
    # `admin_page/` directory).
    class AdminPage < BaseComponent
      def initialize(title: nil, footer: nil, **options)
        super()
        @title = title
        @footer = footer

        assign_options(options)
        @user_attrs = extract_user_attrs(options)
      end

      def extract_user_attrs(options)
        excluded_keys = %i[
          title subtitle actions action_icons search breadcrumbs padding overflow
          content_card turbo_frame turbo_frame_options
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
          div(class: build_classes("flex flex-col gap-4", @user_attrs[:class]),
              **@user_attrs.except(:class)) do
            render_breadcrumbs if @breadcrumbs&.any?
            render_header
            render_content(&block)
            render_footer if @footer.present?
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
        nav(class: "text-sm text-muted-foreground", aria_label: "Breadcrumb") do
          ol(class: "flex items-center flex-wrap gap-y-1") do
            @breadcrumbs.each_with_index do |crumb, index|
              render_breadcrumb_item(crumb, index == @breadcrumbs.size - 1)
            end
          end
        end
      end

      def render_breadcrumb_item(crumb, last)
        li(class: "flex items-center") do
          last ? render_breadcrumb_current(crumb) : render_breadcrumb_link(crumb)
        end
      end

      def render_breadcrumb_current(crumb)
        span(class: "font-medium text-foreground", aria_current: "page") do
          crumb[:label] || crumb[:text]
        end
      end

      def render_breadcrumb_link(crumb)
        a(href: crumb[:url] || crumb[:path], class: "hover:text-foreground transition-colors") do
          span { crumb[:label] || crumb[:text] }
          span(class: "mx-1.5 text-muted-foreground/40 select-none") { "/" }
        end
      end

      def render_header
        return unless @title || @action_icons.any? || @actions.any? || @search

        div(class: "flex flex-col gap-3") { render_header_rows }
      end

      def render_header_rows
        div(class: "flex flex-wrap items-start justify-between gap-4") do
          render_header_title_group
          render_header_actions_icons
        end

        div(class: "flex flex-wrap items-center justify-between gap-3") do
          render_search if @search
          div(class: "flex items-center gap-2 flex-wrap") { render_header_action_buttons }
        end
      end

      def render_header_title_group
        return unless @title || @subtitle

        div(class: "min-w-0") do
          h1(class: "text-lg font-semibold tracking-tight text-foreground truncate") { @title } if @title
          p(class: "text-sm text-muted-foreground mt-0.5") { @subtitle } if @subtitle
        end
      end

      def render_header_actions_icons
        return unless @action_icons.any?

        div(class: "flex items-center gap-2 flex-wrap") do
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
                  class: "inline") do
          button(type: "submit", **icon_attrs(action)) { render_icon(action[:icon]) }
        end
      end

      def icon_attrs(action)
        attrs = base_icon_attrs(action)
        data = action[:data]
        attrs[:data] = data if data
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
        svg(class: "w-5 h-5", fill: "none", stroke: "currentColor",
            viewBox: "0 0 24 24") do |s|
          s.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: path)
        end
      end

      def svg_icon_hash(icon)
        svg(class: "w-5 h-5",
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
        base = "inline-flex items-center justify-center rounded-lg px-3 py-2 " \
               "text-sm font-medium transition-colors"
        secondary = "bg-white text-foreground border border-border shadow-sm hover:bg-muted"
        variant = action_primary?(action) ? primary_action_classes : secondary
        attrs = { class: build_classes(base, variant, action[:class]) }
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
          a(href: url, **attrs) { label }
        else
          render_form_action(url, method, attrs, label)
        end
      end

      def render_form_action(url, method, attrs, label)
        form_with(url: url, method: method, class: "inline") do
          button(type: "submit", **attrs) { label }
        end
      end

      def render_content(&)
        div(class: "flex-1 flex flex-col min-h-0") do
          if @content_card
            div(
              class: "bg-white rounded-xl border border-border/60 shadow-sm ring-1 ring-black/[0.03] " \
                     "p-5 sm:p-6 flex-1 flex flex-col min-h-0"
            ) { yield if block_given? }
          elsif block_given?
            yield
          end
        end
      end

      def render_footer
        div(class: "mt-4") do
          case @footer
          when Proc
            instance_exec(&@footer)
          else
            plain @footer
          end
        end
      end

      def render_search
        opts = @search.kind_of?(Hash) ? @search : { placeholder: "Search" }
        form_with(url: opts[:url] || "#", method: :get, class: "w-full sm:w-auto",
                  data: { turbo_frame: opts[:turbo_frame] || "admin_table_content" }) do
          div(class: "relative flex items-center") do
            span(class: "absolute left-3 text-muted-foreground pointer-events-none") do
              svg_icon_path("M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z")
            end
            input(
              type: "search",
              name: opts[:name] || "q",
              placeholder: opts[:placeholder] || "Search",
              class: "h-9 w-full sm:w-72 pl-10 pr-3 text-sm rounded-lg bg-white border border-border " \
                     "shadow-sm focus:outline-none focus:ring-2 focus:ring-primary/20",
              value: opts[:value],
              data: { action: "input->turbo-frame#submit" }
            )
          end
        end
      end

      def get_method?(method)
        [:get, "get"].include?(method)
      end

      def assign_options(options)
        @subtitle = options[:subtitle]
        @actions = options[:actions] || []
        @action_icons = options[:action_icons] || []
        @search = options[:search]
        @breadcrumbs = options[:breadcrumbs]
        @padding = options.fetch(:padding, false)
        @overflow = options.fetch(:overflow, true)
        @content_card = options.fetch(:content_card, true)
        @turbo_frame = options[:turbo_frame]
        @turbo_frame_options = options[:turbo_frame_options]
      end

      def base_icon_attrs(action)
        label = action[:title] || action[:label] || ""
        {
          class: build_classes(icon_base_classes, icon_color_classes(action[:color])),
          title: label,
          aria_label: label
        }
      end

      def icon_color_classes(color)
        icon_color_class_map.fetch((color || "blue").to_s, icon_color_class_map["blue"])
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

      def icon_base_classes
        "inline-flex items-center justify-center size-9 rounded-md transition-colors"
      end

      def primary_action_classes
        "bg-primary text-primary-foreground hover:bg-primary/90 shadow-sm"
      end
    end
  end
end
