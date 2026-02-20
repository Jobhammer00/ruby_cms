# frozen_string_literal: true

module RubyCms
  # Stores configuration preferences for the CMS admin interface.
  # Preferences are key-value pairs with optional type casting.
  class Preference < ::ApplicationRecord
    self.table_name = "preferences"

    VALUE_TYPES = %w[string integer boolean json].freeze

    validates :key, presence: true, uniqueness: true
    validates :value_type, inclusion: { in: VALUE_TYPES }

    def self.get(key, default: nil)
      pref = find_by(key: key.to_s)
      return default if pref.nil?

      pref.typed_value
    end

    def self.set(key, value)
      pref = find_or_initialize_by(key: key.to_s)
      pref.assign_value(value)
      pref.save!
      pref.typed_value
    end

    def self.all_as_hash
      all.each_with_object({}) do |pref, hash|
        hash[pref.key.to_sym] = pref.typed_value
      end
    end

    def self.ensure_defaults!
      defaults.each do |key, config|
        next if exists?(key: key.to_s)

        create!(
          key: key.to_s,
          value: serialize_seed_value(config[:value], config[:type]),
          value_type: config[:type],
          description: config[:description],
          category: config[:category] || "general"
        )
      end
    end

    def self.by_category
      all.group_by(&:category)
    end

    def self.defaults
      RubyCms::SettingsRegistry.defaults_hash
    end

    def typed_value
      case value_type
      when "integer"
        value.to_i
      when "boolean"
        ActiveModel::Type::Boolean.new.cast(value)
      when "json"
        JSON.parse(value)
      else
        value
      end
    rescue JSON::ParserError, StandardError
      value
    end

    def assign_value(new_value)
      self.value_type ||= detect_type(new_value)
      self.value = serialize_value(new_value)
    end

    class << self
      private

      def serialize_seed_value(val, type)
        case type.to_s
        when "json"
          val.to_json
        when "boolean"
          ActiveModel::Type::Boolean.new.cast(val).to_s
        else
          val.to_s
        end
      end
    end

    private

    def detect_type(val)
      case val
      when Integer then "integer"
      when TrueClass, FalseClass then "boolean"
      when Hash, Array then "json"
      else "string"
      end
    end

    def serialize_value(val)
      case val
      when Hash, Array then val.to_json
      else val.to_s
      end
    end
  end
end
