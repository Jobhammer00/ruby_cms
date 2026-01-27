# frozen_string_literal: true

require "yaml"

module RubyCms
  # Service class for syncing content blocks between database and YAML locale files
  class ContentBlocksSync
    class Error < StandardError; end

    def initialize(namespace: nil, locales_dir: nil)
      @namespace = namespace || get_default_namespace
      @locales_dir = locales_dir || Rails.root.join("config/locales")
    end

    # Export all published content blocks to YAML files
    # Creates/updates locale files for each locale configured in I18n.available_locales
    # @param only_published [Boolean] If true, only export published blocks
    # @param flatten_keys [Boolean] If true, flatten dot-separated keys into nested structure
    # @return [Hash] Summary of exported blocks per locale
    def export_to_yaml(only_published: true, flatten_keys: false)
      scope = only_published ? RubyCms::ContentBlock.published : RubyCms::ContentBlock.all

      # Group blocks by locale
      blocks_by_locale = scope.order(:key).group_by(&:locale)

      summary = {}
      I18n.available_locales.each do |locale|
        locale_str = locale.to_s
        locale_file = @locales_dir.join("#{locale}.yml")
        blocks = blocks_by_locale[locale_str] || []
        blocks_hash = blocks.index_by(&:key)
        summary[locale] =
          update_locale_file(locale_file, locale, blocks_hash, flatten_keys:)
      end

      summary
    end

    # Import content blocks from YAML locale files to database
    # @param locale [Symbol, String] Specific locale to import, or nil for all locales
    # @param create_missing [Boolean] Create content blocks that don't exist in DB
    # @param update_existing [Boolean] Update existing content blocks
    # @param published [Boolean] Set published status for imported blocks
    # @return [Hash] Summary of imported/updated blocks
    def import_from_yaml(locale: nil, create_missing: true, update_existing: true, published: false)
      locales_to_process = locale ? [locale.to_sym] : I18n.available_locales
      summary = { created: 0, updated: 0, skipped: 0, errors: [] }

      locales_to_process.each do |loc|
        locale_file = @locales_dir.join("#{loc}.yml")
        next unless locale_file.exist?

        begin
          locale_data = YAML.load_file(locale_file)
          blocks_data = extract_blocks_from_locale(locale_data, loc)

          blocks_data.each do |key, content|
            result = import_block(key, content, loc.to_s, create_missing, update_existing,
                                  published)
            summary[result[:action]] += 1
            summary[:errors] << result[:error] if result[:error]
          end
        rescue StandardError => e
          summary[:errors] << "Error processing #{loc}: #{e.message}"
        end
      end

      summary
    end

    # Sync: export database to YAML, then optionally import from YAML
    # Useful for keeping both in sync
    # @param import_after_export [Boolean] Import from YAML after exporting
    # @return [Hash] Summary of operations
    def sync(import_after_export: false)
      result = { export: {}, import: {} }

      # Export database to YAML
      result[:export] = export_to_yaml

      # Optionally import from YAML (useful for seeding from YAML)
      result[:import] = import_from_yaml if import_after_export

      result
    end

    private

    def get_default_namespace
      Rails.application.config.ruby_cms.content_blocks_translation_namespace
    rescue StandardError
      nil
    end

    def update_locale_file(locale_file, locale, blocks, flatten_keys: false)
      # Load existing locale file or create new structure
      existing_data = if locale_file.exist?
                        YAML.load_file(locale_file) || {}
                      else
                        {}
                      end

      # Ensure locale root exists
      existing_data[locale.to_s] ||= {}

      # Get target hash (namespace or root)
      target_hash = if @namespace.present?
                      existing_data[locale.to_s][@namespace] ||= {}
                      existing_data[locale.to_s][@namespace]
                    else
                      existing_data[locale.to_s]
                    end

      # Update with content blocks
      updated_count = 0
      blocks.each do |key, block|
        content = extract_content_from_block(block)

        if flatten_keys && key.to_s.include?(".")
          # Flatten dot-separated keys into nested structure
          nested_key = unflatten_key(key.to_s, content)
          merge_nested_hash(target_hash, nested_key)
        elsif target_hash[key.to_s] != content
          # Flat key structure
          target_hash[key.to_s] = content
          updated_count += 1
        end
      end

      # Write back to file with proper YAML formatting
      yaml_output = existing_data.to_yaml
      # Ensure proper line endings and formatting
      File.write(locale_file, yaml_output)
      updated_count
    end

    # Convert dot-separated key to nested hash structure
    # Example: "hero.title" => { "hero" => { "title" => content } }
    def unflatten_key(key, content)
      parts = key.split(".")
      result = {}
      current = result

      parts[0..-2].each do |part|
        current[part] = {}
        current = current[part]
      end

      current[parts.last] = content
      result
    end

    # Merge nested hash into target hash
    def merge_nested_hash(target, source)
      source.each do |key, value|
        if value.kind_of?(Hash) && target[key].kind_of?(Hash)
          merge_nested_hash(target[key], value)
        else
          target[key] = value
        end
      end
    end

    def extract_content_from_block(block)
      case block.content_type
      when "rich_text"
        if block.respond_to?(:rich_content) && block.rich_content.present?
          # Export rich text as plain text for YAML (HTML can be preserved if needed)
          # For now, use plain text which is cleaner for YAML files
          block.rich_content.to_plain_text.presence || block.content.to_s
        else
          block.content.to_s
        end
      when "text", "link", "list"
        block.content.to_s
      when "image"
        # For images, store the content (which might be a URL or path)
        block.content.to_s
      else
        block.content.to_s
      end
    end

    def extract_blocks_from_locale(locale_data, locale)
      locale_key = locale.to_s
      return {} unless locale_data[locale_key]

      if @namespace.present?
        namespace_data = locale_data[locale_key][@namespace]
        return {} unless namespace_data

        flatten_hash(namespace_data)
      else
        # Filter out non-content-block keys (like activemodel, etc.)
        filtered = locale_data[locale_key].reject {|k, _v| reserved_keys.include?(k.to_s) }
        flatten_hash(filtered)
      end
    end

    # Flatten nested hash structure to dot-separated keys
    # Example: { hero: { title: "..." } } => { "hero.title" => "..." }
    def flatten_hash(hash, prefix=nil)
      result = {}
      hash.each do |key, value|
        new_key = prefix ? "#{prefix}.#{key}" : key.to_s

        if value.kind_of?(Hash)
          # Recursively flatten nested hashes
          result.merge!(flatten_hash(value, new_key))
        elsif value.kind_of?(Array)
          # Skip arrays (like badges in experience_items)
          # Could be handled differently if needed
          next
        else
          # Leaf value - this is a content block
          result[new_key] = value.to_s
        end
      end
      result
    end

    def reserved_keys
      %w[activemodel activerecord date time number currency support]
    end

    def import_block(key, content, locale, create_missing, update_existing, published)
      block = RubyCms::ContentBlock.find_by(key: key, locale: locale.to_s)

      if block.nil?
        return { action: :skipped, error: nil } unless create_missing

        block = RubyCms::ContentBlock.new(
          key: key,
          locale: locale.to_s,
          content: content.to_s,
          content_type: infer_content_type(content),
          published: published
        )

        if block.save
          { action: :created, error: nil }
        else
          {
            action: :skipped,
            error: "Failed to create #{key} (#{locale}): #{block.errors.full_messages.join(', ')}"
          }
        end
      elsif update_existing
        block.content = content.to_s
        block.published = published if block.published != published
        block.content_type = infer_content_type(content) if block.content_type == "text"

        if block.save
          { action: :updated, error: nil }
        else
          {
            action: :skipped,
            error: "Failed to update #{key} (#{locale}): #{block.errors.full_messages.join(', ')}"
          }
        end
      else
        { action: :skipped, error: nil }
      end
    end

    def infer_content_type(content)
      # Simple heuristic: if content looks like HTML, use rich_text
      content_str = content.to_s
      if content_str.match?(/<[a-z][\s\S]*>/i)
        "rich_text"
      else
        "text"
      end
    end
  end
end
