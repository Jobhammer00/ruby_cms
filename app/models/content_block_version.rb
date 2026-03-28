# frozen_string_literal: true

class ContentBlockVersion < ApplicationRecord
  belongs_to :content_block
  belongs_to :user, optional: true

  EVENTS = %w[create update rollback publish unpublish visual_editor].freeze

  validates :version_number, presence: true,
                             uniqueness: { scope: :content_block_id }
  validates :event, inclusion: { in: EVENTS }

  scope :chronologically, -> { order(version_number: :asc) }
  scope :reverse_chronologically, -> { order(version_number: :desc) }
  scope :preloaded, -> { includes(:user) }

  def diff_from(other)
    fields = %i[title content rich_content_html content_type published]
    fields.each_with_object({}) do |field, changes|
      old_val = other&.public_send(field)
      new_val = public_send(field)
      changes[field] = { old: old_val, new: new_val } if old_val != new_val
    end
  end

  def previous
    content_block.versions.where(version_number: ...version_number)
                 .order(version_number: :desc).first
  end

  def snapshot
    { title:, content:, rich_content_html:, content_type:, published: }
  end
end
