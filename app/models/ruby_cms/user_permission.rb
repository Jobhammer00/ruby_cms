# frozen_string_literal: true

module RubyCms
  class UserPermission < ::ApplicationRecord
    self.table_name = "ruby_cms_user_permissions"

    belongs_to :user, class_name: "User", optional: false
    belongs_to :permission, class_name: "RubyCms::Permission"

    validates :user_id, uniqueness: { scope: :permission_id }
  end
end
