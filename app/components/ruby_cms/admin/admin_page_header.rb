# frozen_string_literal: true

module RubyCms
  module Admin
    # Reusable page header for admin pages.
    # Renders breadcrumbs, title, optional subtitle, and action slot.
    #
    # Usage from ERB:
    #
    #   <%= render RubyCms::Admin::AdminPageHeader.new(
    #     title: "Sports",
    #     breadcrumbs: [
    #       { label: "Admin", url: admin_root_path },
    #       { label: "Sports" }
    #     ]
    #   ) do %>
    #     <%= link_to new_admin_sport_path, class: "..." do %>
    #       + Add
    #     <% end %>
    #   <% end %>
    #
    class AdminPageHeader < BaseComponent
      def initialize(title:, breadcrumbs: [], subtitle: nil, **options)
        super()
        @title = title
        @breadcrumbs = Array(breadcrumbs)
        @subtitle = subtitle
        @header_class = options[:class]
      end

      def view_template(&block)
        header(class: build_classes("flex-shrink-0 mb-4", @header_class)) do
          render_breadcrumbs if @breadcrumbs.any?

          div(class: "flex flex-wrap items-center justify-between gap-4") do
            render_title_section
            render_actions(&block) if block
          end
        end
      end

      private

      def render_title_section
        div(class: "min-w-0") do
          h1(class: "text-lg font-semibold tracking-tight text-foreground") { @title }
          p(class: "text-sm text-muted-foreground mt-0.5") { @subtitle } if @subtitle
        end
      end

      def render_breadcrumbs
        nav(class: "mb-1 text-sm text-muted-foreground", aria_label: "Breadcrumb") do
          ol(class: "flex items-center flex-wrap gap-y-1") do
            @breadcrumbs.each_with_index do |crumb, index|
              render_breadcrumb_item(crumb, last: index == @breadcrumbs.size - 1)
            end
          end
        end
      end

      def render_breadcrumb_item(crumb, last:)
        li(class: "flex items-center") do
          label = crumb[:label] || crumb[:text]

          if last
            span(class: "font-medium text-foreground") { label }
          else
            a(href: crumb[:url] || crumb[:path] || "#", class: "hover:text-foreground transition-colors") { label }
            span(class: "mx-1.5 text-muted-foreground/40 select-none") { "/" }
          end
        end
      end

      def render_actions(&block)
        div(class: "flex items-center gap-3 flex-shrink-0") do
          yield
        end
      end
    end
  end
end
