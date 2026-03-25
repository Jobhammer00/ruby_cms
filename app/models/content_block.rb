# frozen_string_literal: true

# Public ContentBlock model exposed to the host app.
class ContentBlock < ApplicationRecord
  include Publishable
  include Searchable

  self.table_name = "content_blocks"

  def self.action_text_available?
    return false unless defined?(::ActionText::RichText)

    ActiveRecord::Base.connection.data_source_exists?("action_text_rich_texts")
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError,
         ActiveRecord::StatementInvalid
    false
  end

  def self.active_storage_available?
    return false unless defined?(::ActiveStorage::Blob)

    c = ActiveRecord::Base.connection
    c.data_source_exists?("active_storage_blobs") &&
      c.data_source_exists?("active_storage_attachments")
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError,
         ActiveRecord::StatementInvalid
    false
  end

  # Define associations without requiring an active DB connection at boot time.
  # In production, eager loading may happen before AR has connected.
  has_rich_text :rich_content if defined?(::ActionText::RichText)
  has_one_attached :image if defined?(::ActiveStorage::Blob)

  belongs_to :updated_by, class_name: "User", optional: true

  CONTENT_TYPES = %w[text rich_text image link list].freeze

  validates :key, presence: true
  validates :locale, presence: true
  validates :content_type, inclusion: { in: CONTENT_TYPES }
  validates :key, uniqueness: { scope: :locale }
  validate :key_not_reserved
  validate :image_content_type, if: -> { respond_to?(:image) && image.attached? }
  validate :image_size, if: -> { respond_to?(:image) && image.attached? }

  scope :chronologically, -> { order(created_at: :asc) }
  scope :reverse_chronologically, -> { order(created_at: :desc) }
  scope :alphabetically, -> { order(:key) }
  scope :for_locale, ->(locale) { where(locale: locale.to_s) }
  scope :for_current_locale, -> { where(locale: I18n.locale.to_s) }
  scope :preloaded, -> { includes(:updated_by) }

  scope :indexed_by, lambda {|index|
    case index.to_s
    when "published" then published
    when "unpublished" then unpublished
    else all
    end
  }

  scope :sorted_by, lambda {|sort|
    case sort.to_s
    when "latest" then reverse_chronologically
    when "oldest" then chronologically
    else alphabetically
    end
  }

  def self.accessible_by(_user)
    all
  end

  def self.by_key
    alphabetically
  end

  def can_edit?(user)
    user&.can?(:manage_content_blocks, record: self)
  end

  def can_delete?(user)
    user&.can?(:manage_content_blocks, record: self)
  end

  def record_update_by(user)
    self.updated_by = user if user
  end

  def content_body
    if content_type == "rich_text" && self.class.action_text_available? &&
       respond_to?(:rich_content)
      rich_content.to_s
    else
      content.to_s
    end
  end

  def self.find_by_key_and_locale(key, locale: nil, default_locale: nil)
    locale ||= I18n.locale.to_s
    default_locale ||= begin
      I18n.default_locale.to_s
    rescue StandardError
      "en"
    end

    block = find_by(key: key.to_s, locale: locale.to_s)
    return block if block
    return nil if locale.to_s == default_locale.to_s

    find_by(key: key.to_s, locale: default_locale.to_s)
  end

  private

  def key_not_reserved
    prefixes =
      Array(RubyCms::Settings.get(:reserved_key_prefixes, default: ["admin_"])).map(&:to_s)
    return unless key.to_s.start_with?(*prefixes)

    errors.add(:key, :reserved)
  rescue StandardError
    errors.add(:key, :reserved) if key.to_s.start_with?("admin_")
  end

  def image_content_type
    return unless respond_to?(:image) && image.attached?

    return if image.content_type.in?(allowed_image_content_types)

    errors.add(:image, :content_type_invalid)
  rescue StandardError
    errors.add(:image, :content_type_invalid)
  end

  def allowed_image_content_types
    Array(
      RubyCms::Settings.get(
        :image_content_types,
        default: ["image/png", "image/jpeg", "image/gif", "image/webp"]
      )
    ).map(&:to_s)
  rescue StandardError
    ["image/png", "image/jpeg", "image/gif", "image/webp"]
  end

  def image_size
    return unless respond_to?(:image) && image.attached?

    limit = RubyCms::Settings.get(:image_max_size, default: 5 * 1024 * 1024).to_i
    return if image.byte_size <= limit

    errors.add(:image, :file_too_large)
  rescue StandardError
    errors.add(:image, :file_too_large)
  end
end
