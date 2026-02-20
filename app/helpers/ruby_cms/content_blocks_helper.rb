# frozen_string_literal: true

module RubyCms
  module ContentBlocksHelper
    # Renders a content block by key. Rendering uses the block's content_type from the DB (text, rich_text, image, link, list).
    # Usage:
    #   content_block("hero_title")
    #   content_block("hero_title", "Welcome")          # key + default when block missing
    #   content_block("hero_title", default: "Welcome") # same via keyword
    # Wraps in a span with data-content-key, data-block-id, and .content-block for editor hooks.
    def content_block(key, default_or_nil = nil, locale: nil, fallback: nil, default: nil, # rubocop:disable Metrics/ParameterLists,Metrics/MethodLength
                      translation_namespace: nil, **options)
      # Support content_block("key", "Default") and content_block("key", default: "Default")
      default = default_or_nil.is_a?(Hash) ? default : (default_or_nil || default)
      cache_opts = options.delete(:cache)
      wrap = options.delete(:wrap)
      wrap = true if wrap.nil?

      cache_key = cache_key_for_content_block(key, cache_opts)

      if cache_opts && cache_key
        Rails.cache.fetch(cache_key) do
          render_content_block(key, locale, default, fallback, translation_namespace, options,
                               wrap:)
        end
      else
        render_content_block(key, locale, default, fallback, translation_namespace, options, wrap:)
      end
    end

    alias cms_content_block content_block

    # Returns plain text (no HTML wrapper)
    def content_block_text(key, locale: nil, default: nil, fallback: nil,
                           translation_namespace: nil)
      locale = normalize_locale(locale)
      block = find_content_block(key, locale)

      content = content_for_block_text(
        block, default, fallback, key, translation_namespace, locale
      )

      strip_html_tags(content)
    end

    alias cms_content_block_text content_block_text

    # Returns array of strings from list-type content block
    def content_block_list_items(key, locale: nil, fallback: nil)
      locale = normalize_locale(locale)
      block = find_content_block(key, locale)
      return Array(fallback) if block.blank?

      raw = block.content.to_s
      items = parse_list_items(raw)
      items.presence || Array(fallback)
    end

    alias cms_content_block_list_items content_block_list_items

    private

    def normalize_locale(locale)
      (locale || I18n.locale.to_s).to_s
    end

    def find_content_block(key, locale)
      hash = content_blocks_from_context
      return find_block_in_hash(hash, key, locale) if hash

      ::ContentBlock.published.find_by_key_and_locale(key, locale:)
    end

    def content_blocks_from_context
      instance_variable_get(:@content_blocks)
    end

    def find_block_in_hash(hash, key, locale)
      hash.values.find {|b| b.key == key.to_s && b.locale == locale } ||
        hash.values.find {|b| b.key == key.to_s }
    end

    def render_content_block(key, locale, default, fallback, translation_namespace, options, # rubocop:disable Metrics/ParameterLists
                             wrap: true)
      locale = normalize_locale(locale)
      block = find_content_block(key, locale)

      if wrap
        content = content_for_block(block, default, fallback, key, translation_namespace, locale)
        options = options.dup
        options[:tag] = :div if block&.content_type.to_s == "rich_text"
        render_block_wrapper(content, key, options)
      else
        content = content_for_block_text(block, default, fallback, key, translation_namespace,
                                         locale)
        strip_html_tags(content)
      end
    end

    def render_block_wrapper(content, key, options)
      tag_name = options.delete(:tag) || :span
      tag.public_send(tag_name, content, class: build_css_class(options),
                                         data: build_data_attributes(key, options))
    end

    def build_css_class(options)
      ["ruby_cms-content-block", "content-block", options.delete(:class)].compact.join(" ")
    end

    def build_data_attributes(key, options)
      { content_key: key, block_id: key.to_s }.merge(options.delete(:data).to_h)
    end

    def content_for_block(block, default, fallback, key, translation_namespace, locale) # rubocop:disable Metrics/ParameterLists
      if block.present?
        render_content_by_type(block)
      else
        resolve_fallback(default, fallback, key,
                         translation_namespace, locale)
      end
    end

    def content_for_block_text(block, default, fallback, key, translation_namespace, locale) # rubocop:disable Metrics/ParameterLists
      if block.present?
        render_text_content_by_type(block)
      else
        resolve_fallback(default, fallback,
                         key, translation_namespace, locale)
      end
    end

    # Uses block.content_type from the DB (text, rich_text, image, link, list).
    def render_content_by_type(block)
      case block.content_type
      when "rich_text" then render_rich_text_content(block)
      when "image" then content_block_image(block)
      when "link" then content_block_link(block)
      when "list" then content_block_list(block)
      else block.content.to_s
      end
    end

    def render_text_content_by_type(block)
      case block.content_type
      when "rich_text" then render_rich_text_as_text(block)
      when "image", "link" then block_title_or_content(block)
      when "list" then render_list_as_text(block)
      else block.content.to_s
      end
    end

    # Body-only HTML so content stays inside wrapper (no layout div.trix-content / comments).
    def render_rich_text_content(block)
      return block.content.to_s unless action_text_available?(block)
      return block.content.to_s if block.content.present? && !rich_content_body_present?(block)

      html = rich_content_body_html_for_view(block)
      sanitize(html.presence || block.content.to_s)
    end

    def rich_content_body_html_for_view(block)
      return "" unless block.rich_content.respond_to?(:body) && block.rich_content.body.present?

      b = block.rich_content.body
      out = b.respond_to?(:to_html) ? b.to_html : b.to_s
      out.to_s.strip.presence || ""
    end

    def render_rich_text_as_text(block)
      return block.content.to_s unless action_text_available?(block)

      if rich_content_body_present?(block)
        block.rich_content.to_plain_text
      elsif block.content.present?
        block.content.to_s
      else
        safe_rich_text_to_plain_text(block)
      end
    end

    def action_text_available?(block)
      block.class.respond_to?(:action_text_available?) &&
        block.class.action_text_available? &&
        block.respond_to?(:rich_content)
    end

    def rich_content_body_present?(block)
      block.rich_content.respond_to?(:body) && block.rich_content.body.present?
    end

    def safe_rich_text_to_plain_text(block)
      block.rich_content.to_plain_text
    rescue StandardError
      block.content.to_s
    end

    def render_list_as_text(block)
      parse_list_items(block.content.to_s).join(", ")
    end

    def content_block_list(block)
      items = parse_list_items(block.content.to_s)
      return block.content.to_s if items.blank?

      tag.ul(safe_join(items.map {|i| tag.li(i) }))
    end

    def parse_list_items(raw)
      parsed = JSON.parse(raw)
      parsed.kind_of?(Array) ? parsed.map(&:to_s) : split_list_lines(raw)
    rescue JSON::ParserError, TypeError
      split_list_lines(raw)
    end

    def split_list_lines(raw)
      raw.split("\n").map(&:strip).compact_blank
    end

    def content_block_image(block)
      return block.content.to_s unless block.respond_to?(:image) && block.image.attached?

      image_tag(block.image, alt: block.title.presence || block.key)
    end

    def content_block_link(block)
      url = block.content.to_s.strip
      return block.content.to_s if url.blank? || url.start_with?("javascript:", "data:")

      link_to(block.title.presence || url, url)
    end

    def block_title_or_content(block)
      block.title.presence || block.content.to_s
    end

    def resolve_fallback(default, fallback, key, translation_namespace, locale)
      return fallback.to_s if fallback.present?
      return default.to_s if default.present?

      translation = find_translation_fallback(key, translation_namespace, locale)
      translation || key.to_s.humanize
    end

    def find_translation_fallback(key, translation_namespace, locale)
      return unless respond_to?(:t)

      I18n.with_locale(locale) do
        namespace = translation_namespace || translation_namespace_from_config
        try_namespaced_translation(namespace, key) || try_root_translation(key)
      end
    end

    def translation_namespace_from_config
      Rails.application.config.ruby_cms.content_blocks_translation_namespace
    rescue StandardError
      nil
    end

    def try_namespaced_translation(namespace, key)
      return if namespace.blank?

      namespaced_key = "#{namespace}.#{key}"
      translation = t(namespaced_key, default: nil)
      return nil if translation.blank? || translation == namespaced_key

      translation.to_s
    rescue I18n::MissingTranslationData
      nil
    end

    def try_root_translation(key)
      translation = t(key, default: nil)
      return nil if translation.blank? || translation == key.to_s

      translation.to_s
    rescue I18n::MissingTranslationData
      nil
    end

    def strip_html_tags(content)
      if respond_to?(:strip_tags)
        strip_tags(content.to_s)
      else
        content.to_s.gsub(/<[^>]*>/, "").strip
      end
    end

    def cache_key_for_content_block(key, cache_opts)
      return nil unless cache_opts

      block = ::ContentBlock.published.find_by(key: key.to_s)
      part = block ? block.cache_key : "nil"
      ["ruby_cms", "content_block", key.to_s, part].join("/")
    end
  end
end
