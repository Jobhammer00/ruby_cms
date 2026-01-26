# frozen_string_literal: true

module RubyCms
  class PageRegion < ::ApplicationRecord
    self.table_name = "ruby_cms_page_regions"

    belongs_to :page, class_name: "RubyCms::Page", touch: true
    has_many :page_nodes, class_name: "RubyCms::PageNode", dependent: :destroy, foreign_key: "page_region_id"

    validates :key, presence: true
    validates :key, uniqueness: { scope: :page_id }
    validates :key, format: { with: /\A[\w-]+\z/, message: "only letters, numbers, hyphens, and underscores" }

    scope :by_position, -> { order(:position, :key) }

    after_commit :trigger_page_compile, if: -> { page&.builder_mode? }

    private

    def trigger_page_compile
      page&.enqueue_compile if page&.published?
    end
  end
end
