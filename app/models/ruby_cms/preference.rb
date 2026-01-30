# frozen_string_literal: true

module RubyCms
  # Stores configuration preferences for the CMS admin interface.
  # Preferences are key-value pairs with optional type casting.
  #
  # Usage:
  #   RubyCms::Preference.get(:visitor_errors_per_page, default: 25)
  #   RubyCms::Preference.set(:visitor_errors_per_page, 50)
  #
  class Preference < ::ApplicationRecord
    self.table_name = "ruby_cms_preferences"

    validates :key, presence: true, uniqueness: true
    validates :value_type, inclusion: { in: %w[string integer boolean json] }

    # Get a preference value with optional default
    def self.get(key, default: nil)
      pref = find_by(key: key.to_s)
      return default if pref.nil?

      pref.typed_value
    end

    # Set a preference value (creates or updates)
    def self.set(key, value)
      pref = find_or_initialize_by(key: key.to_s)
      pref.assign_value(value)
      pref.save!
      pref.typed_value
    end

    # Get all preferences as a hash
    def self.all_as_hash
      all.each_with_object({}) do |pref, hash|
        hash[pref.key.to_sym] = pref.typed_value
      end
    end

    # Ensure default preferences exist
    def self.ensure_defaults!
      defaults.each do |key, config|
        next if exists?(key:)

        create!(
          key: key,
          value: config[:value].to_s,
          value_type: config[:type],
          description: config[:description],
          category: config[:category] || "general"
        )
      end
    end

    # Get all preferences grouped by category
    def self.by_category
      all.group_by(&:category)
    end

    # Default preferences configuration
    def self.defaults
      {
        # Pagination
        visitor_errors_per_page: {
          value: 25,
          type: "integer",
          description: "Number of visitor errors to show per page",
          category: "pagination"
        },
        content_blocks_per_page: {
          value: 50,
          type: "integer",
          description: "Number of content blocks to show per page",
          category: "pagination"
        },
        users_per_page: {
          value: 50,
          type: "integer",
          description: "Number of users to show per page",
          category: "pagination"
        },
        permissions_per_page: {
          value: 50,
          type: "integer",
          description: "Number of permissions to show per page",
          category: "pagination"
        },
        # Navigation visibility
        nav_show_dashboard: {
          value: true,
          type: "boolean",
          description: "Show Dashboard in navigation",
          category: "navigation"
        },
        nav_show_visual_editor: {
          value: true,
          type: "boolean",
          description: "Show Visual Editor in navigation",
          category: "navigation"
        },
        nav_show_content_blocks: {
          value: true,
          type: "boolean",
          description: "Show Content Blocks in navigation",
          category: "navigation"
        },
        nav_show_settings: {
          value: true,
          type: "boolean",
          description: "Show Settings in navigation",
          category: "navigation"
        },
        nav_show_visitor_errors: {
          value: true,
          type: "boolean",
          description: "Show Visitor Errors in navigation",
          category: "navigation"
        },
        nav_show_permissions: {
          value: true,
          type: "boolean",
          description: "Show Permissions in navigation",
          category: "navigation"
        },
        nav_show_users: {
          value: true,
          type: "boolean",
          description: "Show Users in navigation",
          category: "navigation"
        }
      }
    end

    # Get the value cast to the appropriate type
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

    # Assign a value and auto-detect type if not set
    def assign_value(new_value)
      self.value_type ||= detect_type(new_value)
      self.value = serialize_value(new_value)
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
