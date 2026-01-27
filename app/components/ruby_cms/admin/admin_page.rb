# frozen_string_literal: true

module RubyCms
  module Admin
    # Admin page wrapper component
    # Provides consistent layout for admin pages with header, actions, and content
    #
    # @param title [String] Page title
    # @param subtitle [String, nil] Optional subtitle
    # @param actions [Array<Hash>, nil] Array of action button configs
    # @param breadcrumbs [Array<Hash>, nil] Array of breadcrumb items
    # @param padding [Boolean] Add padding classes (default: true)
    # @param overflow [Boolean] Allow overflow (default: true)
    # @param turbo_frame [String, nil] Turbo Frame ID for wrapping
    # @param turbo_frame_options [Hash, nil] Custom Turbo Frame options
    class AdminPage < BaseComponent
      def initialize(title:, **options)
        super()
        @title = title
        @subtitle = options[:subtitle]
        @actions = options[:actions] || []
        @breadcrumbs = options[:breadcrumbs]
        @padding = options.fetch(:padding, true)
        @overflow = options.fetch(:overflow, true)
        @turbo_frame = options[:turbo_frame]
        @turbo_frame_options = options[:turbo_frame_options]
        @user_attrs = extract_user_attrs(options)
      end

      def extract_user_attrs(options)
        excluded_keys = %i[subtitle actions breadcrumbs padding overflow turbo_frame turbo_frame_options]
        options.reject { |key, _| excluded_keys.include?(key) }
      end

      def view_template(&block)
        content = build_page_content(&block)
        wrap_with_turbo_frame(content, &block)
      end

      def build_page_content(&block)
        lambda do
          div(class: build_admin_page_classes, **@user_attrs) do
            render_breadcrumbs if @breadcrumbs&.any?
            render_header
            render_content(&block)
          end
        end
      end

      def wrap_with_turbo_frame(content, &block)
        if @turbo_frame
          turbo_frame_tag(@turbo_frame, **default_turbo_frame_options, &content)
        else
          content.call
        end
      end

      private

      def build_admin_page_classes
        classes = ["ruby_cms-admin-page"]
        classes << "ruby_cms-admin-page--with-padding" if @padding
        classes << "ruby_cms-admin-page--no-overflow" unless @overflow
        classes.join(" ")
      end

      def default_turbo_frame_options
        defaults = {
          class: "flex-1 flex flex-col min-h-0",
          data: { turbo_action: "advance" }
        }
        @turbo_frame_options ? defaults.merge(@turbo_frame_options) : defaults
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

      def render_breadcrumbs
        nav(class: "ruby_cms-admin-page__breadcrumbs", aria_label: "Breadcrumb") do
          ol(class: "ruby_cms-admin-page__breadcrumb-list") do
            @breadcrumbs.each_with_index do |crumb, index|
              render_breadcrumb_item(crumb, index == @breadcrumbs.length - 1)
            end
          end
        end
      end

      def render_breadcrumb_item(crumb, is_last)
        li(class: "ruby_cms-admin-page__breadcrumb-item") do
          if is_last
            render_breadcrumb_current(crumb)
          else
            render_breadcrumb_link(crumb)
          end
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
        div(class: "ruby_cms-page-header") do
          div(class: "ruby_cms-page-header__content") do
            render_header_title_group
            render_header_actions if @actions.any?
          end
        end
      end

      def render_header_title_group
        div(class: "ruby_cms-page-header__title-group") do
          h1(class: "ruby_cms-page-title") { @title }
          p(class: "ruby_cms-page-subtitle") { @subtitle } if @subtitle
        end
      end

      def render_header_actions
        div(class: "ruby_cms-page-header__actions") do
          @actions.each do |action|
            render_action_button(action)
          end
        end
      end

      def render_content
        div(class: "ruby_cms-admin-page__content") do
          yield if block_given?
        end
      end

      def render_action_button(action)
        return render_raw_html_action(action) if action[:html].present?

        render_standard_action(action)
      end

      def render_raw_html_action(action)
        html_value = action[:html]
        safe_html = prepare_html_for_rendering(html_value)
        # rubocop:disable Rails/OutputSafety
        raw(safe_html)
      end

      def prepare_html_for_rendering(html_value)
        if html_value.respond_to?(:html_safe?) && html_value.html_safe?
          html_value
        elsif html_value.respond_to?(:html_safe)
          # rubocop:disable Rails/OutputSafety
          html_value.html_safe
        else
          # rubocop:disable Rails/OutputSafety
          html_value.to_s.html_safe
        end
      end

      def render_standard_action(action)
        label = extract_action_label(action)
        url = extract_action_url(action)
        method = action[:method] || :get
        attrs = build_action_attributes(action)

        render_action_element(url, method, attrs, label)
      end

      def extract_action_label(action)
        action[:label] || action[:text] || action[:name]&.humanize || "Action"
      end

      def extract_action_url(action)
        action[:url] || action[:path] || "#"
      end

      def build_action_attributes(action)
        class_name = build_action_class_name(action)
        attrs = { class: class_name }
        attrs[:data] = action[:data] if action[:data]
        attrs
      end

      def build_action_class_name(action)
        class_name = "ruby_cms-btn"
        class_name += " #{action[:class]}" if action[:class]
        class_name += " ruby_cms-btn-primary" if should_be_primary?(action)
        class_name += " ruby_cms-btn-secondary" if should_be_secondary?(action)
        class_name
      end

      def should_be_primary?(action)
        action[:primary] != false && action[:style] != "secondary"
      end

      def should_be_secondary?(action)
        action[:style] == "secondary" || action[:primary] == false
      end

      def render_action_element(url, method, attrs, label)
        if get_method?(method)
          a(href: url, **attrs) { label }
        else
          render_form_action(url, method, attrs, label)
        end
      end

      def get_method?(method)
        [:get, "get"].include?(method)
      end

      def render_form_action(url, method, attrs, label)
        form_with(url: url, method: method, class: "ruby_cms-inline-form") do
          button(type: "submit", **attrs) { label }
        end
      end
    end
  end
end
