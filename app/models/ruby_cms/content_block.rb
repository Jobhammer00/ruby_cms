# frozen_string_literal: true

module RubyCms
  class ContentBlock < ::ApplicationRecord
    self.table_name = "ruby_cms_content_blocks"

    # Optional integrations (host app may not have run action_text:install / active_storage:install yet)
    def self.action_text_available?
      return false unless defined?(::ActionText::RichText)
      return false unless ActiveRecord::Base.connected?

      ActiveRecord::Base.connection.data_source_exists?("action_text_rich_texts")
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError
      false
    end

    def self.active_storage_available?
      return false unless defined?(::ActiveStorage::Blob)
      return false unless ActiveRecord::Base.connected?

      c = ActiveRecord::Base.connection
      c.data_source_exists?("active_storage_blobs") && c.data_source_exists?("active_storage_attachments")
    rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError
      false
    end

    has_rich_text :rich_content if action_text_available?
    has_one_attached :image if active_storage_available?

    belongs_to :updated_by, class_name: "User", optional: true

    CONTENT_TYPES = %w[text rich_text image link list].freeze

    validates :key, presence: true
    validates :locale, presence: true
    validates :content_type, inclusion: { in: CONTENT_TYPES }
    validates :key, uniqueness: { scope: :locale, message: "must be unique per locale" }
    validate :key_not_reserved
    validate :image_content_type, if: -> { respond_to?(:image) && image.attached? }
    validate :image_size, if: -> { respond_to?(:image) && image.attached? }

    scope :published, -> { where(published: true) }
    scope :by_key, -> { order(:key) }
    scope :for_locale, ->(locale) { where(locale: locale.to_s) }
    scope :for_current_locale, -> { where(locale: I18n.locale.to_s) }

    # Scope for content blocks accessible by a user
    # Can be extended in the future for per-record permissions
    # @param user [User] The user to check access for
    # @return [ActiveRecord::Relation] Content blocks the user can access
    def self.accessible_by(_user)
      # For now, all content blocks are accessible if user has manage_content_blocks permission
      # Future: Add per-record permission checks here
      all
    end

    def content_body
      case content_type
      when "rich_text"
        if self.class.action_text_available? && respond_to?(:rich_content)
          rich_content.to_s
        else
          content.to_s
        end
      when "text", "link", "list" then content.to_s
      else content.to_s
      end
    end

    # Find content block by key and locale, with fallback to default locale
    # @param key [String] The content block key
    # @param locale [String, Symbol] The locale to find
    # @param default_locale [String, Symbol] Fallback locale if not found
    # @return [ContentBlock, nil] The content block or nil
    def self.find_by_key_and_locale(key, locale: nil, default_locale: nil)
      locale ||= I18n.locale.to_s
      default_locale ||= begin
        I18n.default_locale.to_s
      rescue StandardError
        "en"
      end

      # Try requested locale first
      block = find_by(key: key.to_s, locale: locale.to_s)
      return block if block

      # Fallback to default locale
      return nil if locale.to_s == default_locale.to_s

      find_by(key: key.to_s, locale: default_locale.to_s)
    end

    private

    def key_not_reserved
      prefixes = begin
        Rails.application.config.ruby_cms.reserved_key_prefixes
      rescue StandardError
        nil
      end || %w[admin_]
      return unless key.to_s.start_with?(*prefixes)

      errors.add(:key, :reserved)
    end

    def image_content_type
      return unless respond_to?(:image) && image.attached?

      allowed = begin
        Rails.application.config.ruby_cms.image_content_types
      rescue StandardError
        nil
      end || %w[
        image/png image/jpeg image/gif
        image/webp
      ]
      return if image.content_type.in?(allowed)

      errors.add(:image, :content_type_invalid)
    end

    def image_size
      return unless respond_to?(:image) && image.attached?

      limit = begin
        Rails.application.config.ruby_cms.image_max_size
      rescue StandardError
        5.megabytes
      end
      return if image.byte_size <= limit

      errors.add(:image, :file_too_large)
    end
  end
end
