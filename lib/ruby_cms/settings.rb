# frozen_string_literal: true

require_relative "settings_registry"

module RubyCms
  module Settings
    IMPORT_SENTINEL_KEY = "__internal_initializer_import_v1"

    class << self
      def get(key, default: nil)
        k = key.to_s
        pref = fetch_preference(k)
        return pref.typed_value if pref

        entry = RubyCms::SettingsRegistry.fetch(k)
        return entry.default unless entry.nil?

        default
      end

      def set(key, value)
        raise "Settings table not available yet" unless preference_table_available?

        k = key.to_s
        entry = RubyCms::SettingsRegistry.fetch(k)
        coerced = coerce_by_entry(value, entry)

        RubyCms::Preference.set(k, coerced)
      end

      def ensure_defaults!
        RubyCms::SettingsRegistry.seed_defaults!
        RubyCms::Preference.ensure_defaults!
      end

      def all
        return {} unless preference_table_available?

        RubyCms::Preference.all_as_hash
      end

      # Imports initializer values for any key that exists in SettingsRegistry
      # and is explicitly set on config.ruby_cms.
      def import_initializer_values!(force: false)
        return skipped_result("preferences table unavailable") unless preference_table_available?

        ensure_defaults!

        return skipped_result("already imported") if imported_from_initializer? && !force

        config = ruby_cms_config
        return skipped_result("ruby_cms config unavailable") if config.nil?

        imported_keys = []

        RubyCms::SettingsRegistry.each do |entry|
          key = entry.key.to_sym
          next unless config.respond_to?(key)

          value = config.public_send(key)
          next if value.nil?

          set(key, value)
          imported_keys << entry.key
        end

        mark_imported!(imported_keys)

        {
          skipped: false,
          imported_count: imported_keys.size,
          imported_keys: imported_keys
        }
      rescue StandardError => e
        skipped_result(e.message)
      end

      def imported_from_initializer?
        return false unless preference_table_available?

        RubyCms::Preference.exists?(key: IMPORT_SENTINEL_KEY)
      rescue StandardError
        false
      end

      private

      def skipped_result(reason)
        { skipped: true, reason: reason, imported_count: 0 }
      end

      def ruby_cms_config
        return nil unless defined?(Rails) && Rails.application.config.respond_to?(:ruby_cms)

        Rails.application.config.ruby_cms
      rescue StandardError
        nil
      end

      def mark_imported!(imported_keys)
        RubyCms::Preference.set(
          IMPORT_SENTINEL_KEY,
          {
            version: 1,
            imported_at: Time.current.iso8601,
            imported_keys: imported_keys
          }
        )
      end

      def fetch_preference(key)
        return nil unless preference_table_available?

        RubyCms::Preference.find_by(key:)
      rescue StandardError
        nil
      end

      def preference_table_available?
        return false unless defined?(ActiveRecord::Base) && defined?(RubyCms::Preference)

        ActiveRecord::Base.connection.data_source_exists?("preferences")
      rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        false
      end

      def coerce_by_entry(value, entry)
        return value if entry.nil?

        case entry.type
        when :integer
          value.to_i
        when :boolean
          ActiveModel::Type::Boolean.new.cast(value)
        when :json
          value.kind_of?(String) ? JSON.parse(value) : value
        else
          value.to_s
        end
      rescue JSON::ParserError
        value
      end
    end
  end
end
