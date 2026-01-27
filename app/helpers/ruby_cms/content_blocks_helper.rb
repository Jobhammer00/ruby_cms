# frozen_string_literal: true

module RubyCms
  module ContentBlocksHelper
    # Renders a content block by key. Options: default (when missing), fallback (translation or string), class, cache (key or true).
    # Wraps in a span with data-content-key, data-block-id, and .content-block for editor hooks.
    # Content by type: text, rich_text (Action Text sanitized), image, link, list.
    # Avoid delete_matched: cache keys include the block's cache_key so updates invalidate.
    #
    # @param key [String, Symbol] The content block key
    # @param locale [String, Symbol, nil] The locale to use. If nil, uses I18n.locale
    # @param default [String, nil] Default content when block is missing (deprecated, use fallback)
    # @param fallback [String, nil] Fallback content when block is missing. If nil, attempts translation via I18n.t
    # @param translation_namespace [String, nil] Namespace for translations (e.g., "content_blocks"). If nil, uses config or tries both namespaced and root-level
    # @param options [Hash] Additional options (class, cache, tag, data)
    # @return [String] Rendered HTML with proper data attributes for visual editor
    #
    # @example Basic usage (uses current locale)
    #   content_block("home_hero_title")
    #
    # @example With specific locale
    #   content_block("home_hero_title", locale: :nl)
    #
    # @example With fallback translation (tries content_blocks.home_hero_title, then home_hero_title)
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
    def content_block(key, locale: nil, default: nil, fallback: nil, translation_namespace: nil,
                      **options)
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
    # @param locale [String, Symbol, nil] The locale to use. If nil, uses I18n.locale
    # @param default [String, nil] Default content when block is missing
    # @param fallback [String, nil] Fallback content when block is missing. If nil, attempts translation via I18n.t
    # @param translation_namespace [String, nil] Namespace for translations
    # @return [String] Plain text content (no HTML)
    #
    # @example For input placeholder
    #   text_field_tag :name, nil, placeholder: content_block_text("contact.full_name_placeholder")
    #
    # @example For alt text
    #   image_tag "photo.jpg", alt: content_block_text("image.alt_text")
    def content_block_text(key, locale: nil, default: nil, fallback: nil,
                           translation_namespace: nil)
      # Determine locale to use
      locale ||= I18n.locale.to_s
      locale = locale.to_s

      # Find the block
      block = if @content_blocks.kind_of?(Hash)
                @content_blocks.values.find {|b| b.key == key.to_s && b.locale == locale } ||
                  @content_blocks.values.find {|b| b.key == key.to_s }
              else
                RubyCms::ContentBlock.published.find_by_key_and_locale(key, locale:)
              end

      # Get content (plain text)
      content = content_for_block_text(block, default, fallback, key, translation_namespace, locale)

      # Strip HTML tags and return plain text (safety measure - content_for_block_text should already be plain)
      if respond_to?(:strip_tags)
        strip_tags(content.to_s)
      else
        # Fallback: simple HTML tag removal if strip_tags not available
        content.to_s.gsub(/<[^>]*>/, "").strip
      end
    end

    # Alias for content_block_text
    alias cms_content_block_text content_block_text

    private

    def render_content_block(key, locale, default, fallback, translation_namespace, options)
      # Determine locale to use
      locale ||= I18n.locale.to_s
      locale = locale.to_s

      # In visual editor preview, @content_blocks is set with all blocks (including unpublished)
      # Otherwise, only show published blocks with locale fallback
      block = if @content_blocks.kind_of?(Hash)
                # In preview mode, try to find by locale first
                @content_blocks.values.find {|b| b.key == key.to_s && b.locale == locale } ||
                  @content_blocks.values.find {|b| b.key == key.to_s }
              else
                RubyCms::ContentBlock.published.find_by_key_and_locale(key, locale:)
              end
      content = content_for_block(block, default, fallback, key, translation_namespace, locale)
      css_class = [
        "ruby_cms-content-block", "content-block",
        options.delete(:class)
      ].compact.join(" ")
      data = { content_key: key, block_id: key.to_s }.merge(options.delete(:data).to_h)

      # Use div for block-level elements (better for visual editor), span for inline
      tag_name = options.delete(:tag) || :span
      tag.public_send(tag_name, content, class: css_class, data: data)
    end

    def content_for_block(block, default, fallback, key, translation_namespace, locale)
      return resolve_fallback(default, fallback, key, translation_namespace, locale) unless block

      case block.content_type
      when "rich_text"
        if block.class.respond_to?(:action_text_available?) && block.class.action_text_available? && block.respond_to?(:rich_content)
          # Check if rich_content has a body and if it's present, otherwise fall back to content
          if block.rich_content.respond_to?(:body) && block.rich_content.body.present?
            block.rich_content.to_s.html_safe
          elsif block.content.present?
            block.content.to_s
          else
            block.rich_content.to_s.html_safe
          end
        else
          block.content.to_s
        end
      when "image" then content_block_image(block)
      when "link" then content_block_link(block)
      when "list" then content_block_list(block)
      else block.content.to_s
      end
    end

    def content_for_block_text(block, default, fallback, key, translation_namespace, locale)
      return resolve_fallback(default, fallback, key, translation_namespace, locale) unless block

      case block.content_type
      when "rich_text"
        if block.class.respond_to?(:action_text_available?) && block.class.action_text_available? && block.respond_to?(:rich_content)
          # For text output, use plain text version
          if block.rich_content.respond_to?(:body) && block.rich_content.body.present?
            block.rich_content.to_plain_text
          elsif block.content.present?
            block.content.to_s
          else
            begin
              block.rich_content.to_plain_text
            rescue StandardError
              block.content.to_s
            end
          end
        else
          block.content.to_s
        end
      when "image"
        # For images, return alt text or content
        block.title.presence || block.content.to_s
      when "link"
        # For links, return title or URL
        block.title.presence || block.content.to_s
      when "list"
        # For lists, return plain text representation
        raw = block.content.to_s
        items = begin
          parsed = JSON.parse(raw)
          parsed.kind_of?(Array) ? parsed.map(&:to_s) : raw.split("\n").map(&:strip).reject(&:blank?)
        rescue JSON::ParserError, TypeError
          raw.split("\n").map(&:strip).reject(&:blank?)
        end
        items.join(", ")
      else
        block.content.to_s
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
        parsed.kind_of?(Array) ? parsed.map(&:to_s) : raw.split("\n").map(&:strip).reject(&:blank?)
      rescue JSON::ParserError, TypeError
        raw.split("\n").map(&:strip).reject(&:blank?)
      end
      return raw if items.blank?

      tag.ul(safe_join(items.map {|i| tag.li(i) }))
    end

    def resolve_fallback(default, fallback, key, translation_namespace, locale)
      # Use explicit fallback if provided
      return fallback.to_s if fallback.present?

      # Use default if provided (for backwards compatibility)
      return default.to_s if default.present?

      # Try translation fallback (respects locale)
      if respond_to?(:t)
        # Temporarily set locale for translation lookup
        I18n.with_locale(locale) do
          # Determine namespace to use
          namespace = translation_namespace || get_translation_namespace

          # Try namespaced translation first (if namespace is set)
          if namespace.present?
            namespaced_key = "#{namespace}.#{key}"
            begin
              translation = t(namespaced_key, default: nil)
              return translation.to_s if translation.present? && translation != namespaced_key
            rescue I18n::MissingTranslationData
              # Continue to try root-level
            end
          end

          # Try root-level translation
          begin
            translation = t(key, default: nil)
            return translation.to_s if translation.present? && translation != key.to_s
          rescue I18n::MissingTranslationData
            # Fall through to humanized key
          end
        end
      end

      # Final fallback: humanized key
      key.to_s.humanize
    end

    def get_translation_namespace
      # Check config for default namespace

      Rails.application.config.ruby_cms.content_blocks_translation_namespace
    rescue StandardError
      nil
    end

    def cache_key_for_content_block(key, cache_opts)
      return nil unless cache_opts

      block = RubyCms::ContentBlock.published.find_by(key: key.to_s)
      part = block ? block.cache_key : "nil"
      ["ruby_cms", "content_block", key.to_s, part].join("/")
    end
  end
end
