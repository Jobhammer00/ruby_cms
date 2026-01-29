# frozen_string_literal: true

require "yaml"

module RubyCms
  # Service class for syncing content blocks between database and YAML locale files
  class ContentBlocksSync
    class Error < StandardError; end

    def initialize(namespace: nil, locales_dir: nil)
      @namespace = namespace || default_namespace_from_config
      @locales_dir = locales_dir || Rails.root.join("config/locales")
    end

    # Export all published content blocks to YAML files
    # Creates/updates locale files for each locale configured in I18n.available_locales
    # @param only_published [Boolean] If true, only export published blocks
    # @param flatten_keys [Boolean] If true, flatten dot-separated keys into nested structure
    # @return [Hash] Summary of exported blocks per locale
    def export_to_yaml(only_published: true, flatten_keys: false)
      scope = only_published ? RubyCms::ContentBlock.published : RubyCms::ContentBlock.all
      blocks_by_locale = scope.order(:key).group_by(&:locale)

      summary = {}
      I18n.available_locales.each do |locale|
        summary[locale] = export_locale_to_yaml(
          locale, blocks_by_locale, flatten_keys:
        )
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
        import_locale_from_yaml(
          loc,
          summary,
          create_missing:,
          update_existing:,
          published:
        )
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

    def default_namespace_from_config
      Rails.application.config.ruby_cms.content_blocks_translation_namespace
    rescue StandardError
      nil
    end

    def export_locale_to_yaml(locale, blocks_by_locale, flatten_keys:)
      locale_str = locale.to_s
      locale_file = @locales_dir.join("#{locale}.yml")
      blocks = blocks_by_locale[locale_str] || []
      blocks_hash = blocks.index_by(&:key)
      update_locale_file(locale_file, locale, blocks_hash, flatten_keys:)
    end

    def update_locale_file(locale_file, locale, blocks, flatten_keys: false)
      existing_data = load_existing_locale_data(locale_file)
      locale_root = ensure_locale_root(existing_data, locale)
      target_hash = target_hash_for_locale(locale_root)

      updated_count = update_target_hash(
        target_hash,
        blocks,
        flatten_keys:
      )

      write_locale_file(locale_file, existing_data)
      updated_count
    end

    def load_existing_locale_data(locale_file)
      return {} unless locale_file.exist?

      YAML.load_file(locale_file) || {}
    end

    def ensure_locale_root(existing_data, locale)
      existing_data[locale.to_s] ||= {}
    end

    def target_hash_for_locale(locale_root)
      return locale_root if @namespace.blank?

      locale_root[@namespace] ||= {}
      locale_root[@namespace]
    end

    def update_target_hash(target_hash, blocks, flatten_keys:)
      updated_count = 0

      blocks.each do |key, block|
        updated_count += apply_block_to_target_hash(
          target_hash,
          key,
          block,
          flatten_keys:
        )
      end

      updated_count
    end

    def apply_block_to_target_hash(target_hash, key, block, flatten_keys:)
      content = extract_content_from_block(block)
      key_str = key.to_s

      if flatten_keys && key_str.include?(".")
        merge_nested_hash(target_hash, unflatten_key(key_str, content))
        return 0
      end

      return 0 if target_hash[key_str] == content

      target_hash[key_str] = content
      1
    end

    def write_locale_file(locale_file, existing_data)
      File.write(locale_file, existing_data.to_yaml)
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
      return rich_text_as_plain_text(block) if block.content_type == "rich_text"

      block.content.to_s
    end

    def rich_text_as_plain_text(block)
      return block.content.to_s unless block.respond_to?(:rich_content)
      return block.content.to_s if block.rich_content.blank?

      block.rich_content.to_plain_text.presence || block.content.to_s
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
    def flatten_hash(hash, prefix: nil)
      result = {}
      hash.each do |key, value|
        merge_flattened_value(result, key, value, prefix)
      end
      result
    end

    def merge_flattened_value(result, key, value, prefix)
      new_key = prefix ? "#{prefix}.#{key}" : key.to_s

      if value.kind_of?(Hash)
        result.merge!(flatten_hash(value, prefix: new_key))
        return
      end

      return if value.kind_of?(Array)

      result[new_key] = value.to_s
    end

    def reserved_keys
      %w[activemodel activerecord date time number currency support]
    end

    def import_locale_from_yaml(loc, summary, create_missing:, update_existing:, published:)
      locale_file = @locales_dir.join("#{loc}.yml")
      return unless locale_file.exist?

      locale_data = YAML.load_file(locale_file)
      blocks_data = extract_blocks_from_locale(locale_data, loc)

      assign_blocks_data_to_summary(summary, blocks_data, loc, create_missing:, update_existing:,
                                                               published:)
    rescue StandardError => e
      summary[:errors] << "Error processing #{loc}: #{e.message}"
    end

    def assign_blocks_data_to_summary(summary, blocks_data, locale, create_missing:, # rubocop:disable Metrics/ParameterLists
                                      update_existing:, published:)
      blocks_data.each do |key, content|
        result = import_block(key, content, locale, create_missing:, update_existing:, published:)
        summary[result[:action]] += 1
        summary[:errors] << result[:error] if result[:error]
      end
      summary
    end

    def import_block(key, content, locale, create_missing:, update_existing:, published:) # rubocop:disable Metrics/ParameterLists
      block = RubyCms::ContentBlock.find_by(key: key, locale: locale.to_s)
      return import_new_block(key, content, locale, published) if block.nil? && create_missing
      return { action: :skipped, error: nil } if block.nil?
      return { action: :skipped, error: nil } unless update_existing

      update_existing_block(block, key, content, locale, published)
    end

    def import_new_block(key, content, locale, published)
      block = RubyCms::ContentBlock.new(
        key: key,
        locale: locale.to_s,
        content: content.to_s,
        content_type: infer_content_type(content),
        published: published
      )

      save_block(block, key, locale, action: :created, failure_verb: "create")
    end

    def update_existing_block(block, key, content, locale, published)
      block.content = content.to_s
      block.published = published if block.published != published
      set_inferred_type_if_text(block, content)

      save_block(block, key, locale, action: :updated, failure_verb: "update")
    end

    def set_inferred_type_if_text(block, content)
      return unless block.content_type == "text"

      block.content_type = infer_content_type(content)
    end

    def save_block(block, key, locale, action:, failure_verb:)
      return { action: action, error: nil } if block.save

      { action: :skipped, error: block_failure_message(block, key, locale, failure_verb) }
    end

    def block_failure_message(block, key, locale, failure_verb)
      errors = block.errors.full_messages.join(", ")
      "Failed to #{failure_verb} #{key} (#{locale}): #{errors}"
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
