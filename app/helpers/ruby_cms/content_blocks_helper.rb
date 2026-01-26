# frozen_string_literal: true

module RubyCms
  module ContentBlocksHelper
    # Renders a content block by key. Options: default (when missing), class, cache (key or true).
    # Wraps in a span with data-content-key, data-block-id, and .content-block for editor hooks.
    # Content by type: text, rich_text (Action Text sanitized), image, link, list.
    # Avoid delete_matched: cache keys include the block's cache_key so updates invalidate.
    def content_block(key, default: nil, **options)
      cache_opts = options.delete(:cache)
      cache_key = cache_key_for_content_block(key, cache_opts)

      if cache_opts && cache_key
        Rails.cache.fetch(cache_key) { render_content_block(key, default, options) }
      else
        render_content_block(key, default, options)
      end
    end

    private

    def render_content_block(key, default, options)
      block = RubyCms::ContentBlock.published.find_by(key: key.to_s)
      content = content_for_block(block, default)
      css_class = ["content-block", options.delete(:class)].compact.join(" ")
      data = { content_key: key, block_id: block&.id }.merge(options.delete(:data).to_h)

      tag.span(content, class: css_class, data: data)
    end

    def content_for_block(block, default)
      return default.to_s unless block

      case block.content_type
      when "rich_text"
        if block.class.respond_to?(:action_text_available?) && block.class.action_text_available? && block.respond_to?(:rich_content)
          block.rich_content.to_s.html_safe
        else
          block.content.to_s
        end
      when "image" then content_block_image(block)
      when "link" then content_block_link(block)
      when "list" then content_block_list(block)
      else block.content.to_s
      end
    end

    def content_block_image(block)
      return block.content.to_s unless block.respond_to?(:image) && block.image.attached?

      image_tag(block.image, alt: block.title.presence || block.key)
    end

    def content_block_link(block)
      url = block.content.to_s.strip
      return block.content.to_s if url.blank?
      return block.content.to_s if url.start_with?("javascript:", "data:")

      link_to(block.title.presence || url, url)
    end

    def content_block_list(block)
      raw = block.content.to_s
      items = begin
        parsed = JSON.parse(raw)
        parsed.is_a?(Array) ? parsed.map(&:to_s) : raw.split(/\n/).map(&:strip).reject(&:blank?)
      rescue JSON::ParserError, TypeError
        raw.split(/\n/).map(&:strip).reject(&:blank?)
      end
      return raw if items.blank?

      tag.ul(safe_join(items.map { |i| tag.li(i) }))
    end

    def cache_key_for_content_block(key, cache_opts)
      return nil unless cache_opts

      block = RubyCms::ContentBlock.published.find_by(key: key.to_s)
      part = block ? block.cache_key : "nil"
      ["ruby_cms", "content_block", key.to_s, part].join("/")
    end
  end
end
