# frozen_string_literal: true

module RubyCms
  module PageRendererHelper
    # Render a CMS page based on its render_mode
    # @param page [RubyCms::Page] The page to render
    # @return [String] Rendered HTML
    def render_cms_page(page)
      case page.render_mode
      when "builder"
        render_builder_page(page)
      when "html"
        render_html_page(page)
      when "template"
        # Template mode is handled by controller, not here
        raise ArgumentError, "Template mode should be rendered via controller, not helper"
      else
        raise ArgumentError, "Unknown render_mode: #{page.render_mode}"
      end
    end

    # Render a builder page (regions + nodes)
    # @param page [RubyCms::Page] The page to render
    # @return [String] Rendered HTML
    def render_builder_page(page)
      regions = page.page_regions.includes(page_nodes: :children).by_position

      return "" if regions.empty?

      safe_join(regions.map { |region| render_page_region(region) })
    end

    # Render a single page region with its nodes
    # @param region [RubyCms::PageRegion] The region to render
    # @return [String] Rendered HTML
    def render_page_region(region)
      nodes = region.page_nodes.root_nodes.by_position
      return "" if nodes.empty?

      tag.div(class: "ruby-cms-region", data: { region_key: region.key }) do
        safe_join(nodes.map { |node| render_page_node(node) })
      end
    end

    # Render a page node (component) recursively
    # @param node [RubyCms::PageNode] The node to render
    # @return [String] Rendered HTML
    def render_page_node(node)
      children = node.children.by_position

      if children.any?
        # Render component with children as block content
        RubyCms.render_component(self, node.component_key, node.props || {}) do
          safe_join(children.map { |child| render_page_node(child) })
        end
      else
        # Render component without children
        RubyCms.render_component(self, node.component_key, node.props || {})
      end
    end

    # Render an HTML page (sanitized body_html)
    # @param page [RubyCms::Page] The page to render
    # @return [String] Rendered HTML
    def render_html_page(page)
      return "" unless page.body_html.present?

      # Sanitize HTML for safety (style attribute removed to prevent CSS injection)
      sanitize(page.body_html,
               tags: %w[p div span h1 h2 h3 h4 h5 h6 ul ol li a img strong em b i u br hr blockquote pre code table thead tbody tr td th], attributes: %w[href src alt title class id])
    end
  end
end
