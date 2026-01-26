# frozen_string_literal: true

module RubyCms
  class PageVersion < ::ApplicationRecord
    self.table_name = "ruby_cms_page_versions"

    belongs_to :page, class_name: "RubyCms::Page"
    belongs_to :created_by, class_name: "User", optional: true

    validates :version_number, presence: true, uniqueness: { scope: :page_id }
    validates :version_number, numericality: { greater_than: 0 }

    scope :by_version, -> { order(version_number: :desc) }
    scope :recent, -> { order(created_at: :desc) }

    # Get the previous version
    def previous
      page.page_versions.where("version_number < ?", version_number).order(version_number: :desc).first
    end

    # Get the next version
    def next
      page.page_versions.where("version_number > ?", version_number).order(version_number: :asc).first
    end

    # Check if this is the latest version
    def latest?
      version_number == page.page_versions.maximum(:version_number)
    end
  end
end
