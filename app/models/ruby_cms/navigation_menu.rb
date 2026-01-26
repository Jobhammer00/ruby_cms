# frozen_string_literal: true

module RubyCms
  class NavigationMenu < ::ApplicationRecord
    self.table_name = "ruby_cms_navigation_menus"

    has_many :navigation_items, class_name: "RubyCms::NavigationItem", dependent: :destroy,
                                foreign_key: "navigation_menu_id"
    has_many :root_items, lambda {
      where(parent_id: nil)
    }, class_name: "RubyCms::NavigationItem", foreign_key: "navigation_menu_id"

    validates :key, presence: true, uniqueness: true
    validates :key, format: { with: /\A[\w-]+\z/, message: "only letters, numbers, hyphens, and underscores" }
    validates :name, presence: true

    scope :published, -> { where(published: true) }
    scope :by_position, -> { order(:position, :key) }

    # Get the resolved navigation items for rendering
    def resolved_items(view_context)
      root_items.includes(:children).published.by_position.map do |item|
        item.resolve(view_context)
      end
    end
  end
end
