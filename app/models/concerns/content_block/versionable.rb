# frozen_string_literal: true

module ContentBlock::Versionable # rubocop:disable Style/ClassAndModuleChildren
  extend ActiveSupport::Concern

  included do
    has_many :versions, class_name: "ContentBlockVersion",
                        dependent: :destroy
    after_create :create_initial_version
    after_update :create_update_version, if: :content_changed_meaningfully?

    attr_accessor :_rollback_in_progress
  end

  def rollback_to_version!(version, user: nil)
    transaction do
      self._rollback_in_progress = true
      assign_attributes(
        title: version.title,
        content: version.content,
        content_type: version.content_type,
        published: version.published
      )
      restore_rich_content(version) if version.rich_content_html.present?
      self.updated_by = user if user
      save!
    end
  ensure
    self._rollback_in_progress = false
  end

  def current_version_number
    versions.maximum(:version_number) || 0
  end

  private

  def content_changed_meaningfully?
    saved_change_to_title? || saved_change_to_content? ||
      saved_change_to_content_type? || saved_change_to_published?
  end

  def create_initial_version
    create_version_record(event: "create")
  end

  def create_update_version
    create_version_record(event: determine_event)
  end

  def determine_event
    return "rollback" if _rollback_in_progress
    return "publish" if saved_change_to_published? && published?
    return "unpublish" if saved_change_to_published? && !published?

    "update"
  end

  def create_version_record(event:)
    rich_html = (rich_content.body&.to_html.to_s if respond_to?(:rich_content) && rich_content.respond_to?(:body))

    versions.create!(
      user: updated_by,
      version_number: current_version_number + 1,
      title: title,
      content: content,
      rich_content_html: rich_html,
      content_type: content_type,
      published: published?,
      event: event,
      metadata: { changed_fields: previous_changes.keys }
    )
  end

  def restore_rich_content(version)
    return unless respond_to?(:rich_content=) && version.rich_content_html.present?

    self.rich_content = version.rich_content_html
  end
end
