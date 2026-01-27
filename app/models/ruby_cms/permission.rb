# frozen_string_literal: true

module RubyCms
  class Permission < ::ApplicationRecord
    self.table_name = "ruby_cms_permissions"

    has_many :user_permissions, dependent: :destroy, class_name: "RubyCms::UserPermission"
    has_many :users, through: :user_permissions

    validates :key, presence: true, uniqueness: true

    DEFAULT_KEYS = %w[
      manage_admin
      manage_permissions
      manage_content_blocks
      manage_pages
      publish_pages
    ].freeze

    class << self
      def ensure_defaults!
        DEFAULT_KEYS.each do |k|
          find_or_create_by!(key: k) {|p| p.name = k.humanize }
        end
      end
    end
  end
end
