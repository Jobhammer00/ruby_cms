# frozen_string_literal: true

module RubyCms
  module ContentBlocksHelper
    # Renders a content block by key. Options: default (when missing),
    # fallback (translation or string), class, cache (key or true).
    # Wraps in a span with data-content-key, data-block-id,
    # and .content-block for editor hooks.
    # Content by type: text, rich_text (Action Text sanitized), image, link, list.
    # Avoid delete_matched: cache keys include the block's cache_key
    # so updates invalidate.
    #
    # @param key [String, Symbol] The content block key
    # @param locale [String, Symbol, nil] The locale to use.
    #   If nil, uses I18n.locale
    # @param default [String, nil] Default content when block is missing
    #   (deprecated, use fallback)
    # @param fallback [String, nil] Fallback content when block is missing.
    #   If nil, attempts translation via I18n.t
    # @param translation_namespace [String, nil] Namespace for translations
    #   (e.g., "content_blocks"). If nil, uses config or tries both
    #   namespaced and root-level
    # @param options [Hash] Additional options (class, cache, tag, data)
    # @return [String] Rendered HTML with proper data attributes
    #   for visual editor
    #
    # @example Basic usage (uses current locale)
    #   content_block("home_hero_title")
    #
    # @example With specific locale
    #   content_block("home_hero_title", locale: :nl)
    #
    # @example With fallback translation
    #   (tries content_blocks.home_hero_title, then home_hero_title)
    #   content_block("home_hero_title", fallback: nil)
    #
    # @example With explicit translation namespace
    #   content_block("home_hero_title", translation_namespace: "cms")
    #   # Tries: cms.home_hero_title, then home_hero_title
    #
    # @example With explicit fallback
    #   content_block("home_hero_title", fallback: "Welcome")
    #
    # @example With caching
    #   content_block("home_hero_title", cache: true)
    def content_block(key, locale: nil, default: nil, fallback: nil,
                      translation_namespace: nil, **options)
      cache_opts = options.delete(:cache)
      cache_key = cache_key_for_content_block(key, cache_opts)

      if cache_opts && cache_key
        Rails.cache.fetch(cache_key) do
          render_content_block(key, locale, default, fallback, translation_namespace, options)
        end
      else
        render_content_block(key, locale, default, fallback, translation_namespace, options)
      end
    end

    # Alias for content_block for backwards compatibility
    # Use content_block for consistency with the gem's API
    alias cms_content_block content_block

    # Returns plain text content from a content block (no HTML wrapper)
    # Use this for attributes like placeholder, title, alt text, etc.
    #
    # @param key [String, Symbol] The content block key
    # @param locale [String, Symbol, nil] The locale to use.
    #   If nil, uses I18n.locale
    # @param default [String, nil] Default content when block is missing
    # @param fallback [String, nil] Fallback content when block is missing.
    #   If nil, attempts translation via I18n.t
    # @param translation_namespace [String, nil] Namespace for translations
    # @return [String] Plain text content (no HTML)
    #
    # @example For input placeholder
    #   text_field_tag :name, nil,
    #     placeholder: content_block_text("contact.full_name_placeholder")
    #
    # @example For alt text
    #   image_tag "photo.jpg", alt: content_block_text("image.alt_text")
    def content_block_text(key, locale: nil, default: nil, fallback: nil,
                           translation_namespace: nil)
      locale = normalize_locale(locale)
      block = find_content_block(key, locale)
      content = content_for_block_text(
        block,
        default,
        fallback, key,
        translation_namespace,
        locale
      )
      strip_html_tags(content)
    end

    # Alias for content_block_text
    alias cms_content_block_text content_block_text

    private

    def normalize_locale(locale)
      (locale || I18n.locale.to_s).to_s
    end

    def find_content_block(key, locale)
      content_blocks_hash = content_blocks_from_context
      return find_block_in_hash(content_blocks_hash, key, locale) if content_blocks_hash

      ::ContentBlock.published.find_by_key_and_locale(key, locale:)
    end

    def content_blocks_from_context
      # In visual editor preview, @content_blocks is set with all blocks
      # (including unpublished). We need to access it via instance_variable_get
      # to avoid Rails/HelperInstanceVariable error
      instance_variable_get(:@content_blocks)
    end

    def find_block_in_hash(hash, key, locale)
      hash.values.find {|b| b.key == key.to_s && b.locale == locale } ||
        hash.values.find {|b| b.key == key.to_s }
    end

    def render_content_block(key, locale, default, fallback,
                             translation_namespace, options)
      locale = normalize_locale(locale)
      block = find_content_block(key, locale)
      content = content_for_block(
        block,
        default,
        fallback,
        key,
        translation_namespace,
        locale
      )
      render_block_wrapper(content, key, options)
    end

    def render_block_wrapper(content, key, options)
      css_class = build_css_class(options)
      data = build_data_attributes(key, options)
      tag_name = options.delete(:tag) || :span
      tag.public_send(tag_name, content, class: css_class, data: data)
    end

    def build_css_class(options)
      [
        "ruby_cms-content-block", "content-block",
        options.delete(:class)
      ].compact.join(" ")
    end

    def build_data_attributes(key, options)
      { content_key: key, block_id: key.to_s }
        .merge(options.delete(:data).to_h)
    end

    def content_for_block(block, default, fallback, key,
                          translation_namespace, locale)
      if block.blank?
        resolve_fallback(default, fallback, key, translation_namespace, locale)
      else
        render_content_by_type(block)
      end
    end

    def render_content_by_type(block)
      case block.content_type
      when "rich_text"
        render_rich_text_content(block)
      when "image"
        content_block_image(block)
      when "link"
        content_block_link(block)
      when "list"
        content_block_list(block)
      else
        block.content.to_s
      end
    end

    def render_rich_text_content(block)
      return block.content.to_s unless action_text_available?(block)

      # rubocop:disable Rails/OutputSafety
      # Rich content is trusted content from the CMS
      if block.content.present? && !rich_content_body_present?(block)
        block.content.to_s
      else
        block.rich_content.to_s.html_safe
      end
      # rubocop:enable Rails/OutputSafety
    end

    def action_text_available?(block)
      block.class.respond_to?(:action_text_available?) &&
        block.class.action_text_available? &&
        block.respond_to?(:rich_content)
    end

    def rich_content_body_present?(block)
      block.rich_content.respond_to?(:body) &&
        block.rich_content.body.present?
    end

    def content_for_block_text(block, default, fallback, key,
                               translation_namespace, locale)
      if block.blank?
        resolve_fallback(
          default, fallback, key, translation_namespace, locale
        )
      else
        render_text_content_by_type(block)
      end
    end

    def render_text_content_by_type(block)
      case block.content_type
      when "rich_text"
        render_rich_text_as_text(block)
      when "image", "link"
        block_title_or_content(block)
      when "list"
        render_list_as_text(block)
      else
        block.content.to_s
      end
    end

    def block_title_or_content(block)
      block.title.presence || block.content.to_s
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

    def safe_rich_text_to_plain_text(block)
      block.rich_content.to_plain_text
    rescue StandardError
      block.content.to_s
    end

    def render_list_as_text(block)
      raw = block.content.to_s
      items = parse_list_items(raw)
      items.join(", ")
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
      return block.content.to_s if url.blank?
      return block.content.to_s if url.start_with?("javascript:", "data:")

      link_to(block.title.presence || url, url)
    end

    def content_block_list(block)
      raw = block.content.to_s
      items = parse_list_items(raw)
      return raw if items.blank?

      tag.ul(safe_join(items.map {|i| tag.li(i) }))
    end

    def resolve_fallback(default, fallback, key, translation_namespace, locale)
      return fallback.to_s if fallback.present?
      return default.to_s if default.present?

      translation = find_translation_fallback(key, translation_namespace, locale)
      return translation if translation

      key.to_s.humanize
    end

    def find_translation_fallback(key, translation_namespace, locale)
      return unless respond_to?(:t)

      I18n.with_locale(locale) do
        namespace = translation_namespace || translation_namespace_from_config
        namespaced_translation = try_namespaced_translation(namespace, key)
        return namespaced_translation if namespaced_translation

        try_root_translation(key)
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
