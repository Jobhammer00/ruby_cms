# frozen_string_literal: true

module RubyCms
  class TemplateRegistry
    # Register default/built-in templates
    module Defaults
      def self.register_all
        registry = RubyCms.template_registry

        # Simple landing page template
        registry.register(
          key: "landing/simple",
          name: "Simple Landing Page",
          description: "A basic landing page with hero section and content area",
          layout: "pages/landing",
          regions: [
            {
              key: "main",
              position: 0,
              nodes: [
                {
                  component_key: "primitive.section",
                  props: { padding: "py-16" }
                },
                {
                  component_key: "primitive.container",
                  props: { max_width: "7xl", padding: "4" }
                },
                {
                  component_key: "primitive.heading",
                  props: { text: "Welcome", level: "h1", size: "text-4xl" }
                },
                {
                  component_key: "primitive.text",
                  props: { text: "This is a simple landing page template." }
                }
              ]
            }
          ],
          content_block_keys: %w[hero_title hero_subtitle main_content]
        )

        # Blog post template
        registry.register(
          key: "blog/post",
          name: "Blog Post",
          description: "A blog post layout with title, content, and sidebar",
          layout: "pages/blog_post",
          regions: [
            {
              key: "main",
              position: 0,
              nodes: [
                {
                  component_key: "primitive.container",
                  props: { max_width: "5xl", padding: "4" }
                },
                {
                  component_key: "primitive.heading",
                  props: { text: "Blog Post Title", level: "h1", size: "text-3xl" }
                },
                {
                  component_key: "primitive.text",
                  props: { text: "Blog post content goes here." }
                }
              ]
            }
          ],
          content_block_keys: %w[post_title post_content post_author]
        )
      end
    end
  end
end
