# frozen_string_literal: true

module RubyCms
  class Permission < ::ApplicationRecord
    self.table_name = "permissions"

    has_many :user_permissions, dependent: :destroy, class_name: "RubyCms::UserPermission"
    has_many :users, through: :user_permissions

    validates :key, presence: true, uniqueness: true

    DEFAULT_KEYS = RubyCms::DEFAULT_PERMISSION_KEYS

    class << self
      def ensure_defaults!
        all_keys.each do |k|
          find_or_create_by!(key: k) {|p| p.name = k.titleize }
        end
      end

      def all_keys
        (DEFAULT_KEYS + RubyCms.extra_permission_keys.map(&:to_s)).uniq.freeze
      end

      def templates
        RubyCms.permission_templates
      end

      def register_keys(*keys)
        RubyCms.register_permission_keys(*keys)
      end

      def register_template(name, label:, keys:, description: nil)
        RubyCms.register_permission_template(name, label:, keys:, description:)
      end

      def apply_template!(user, template_name)
        tmpl = templates[template_name.to_sym]
        raise ArgumentError, "Unknown template: #{template_name}" unless tmpl

        ensure_defaults!
        perms = where(key: tmpl[:keys])
        perms.each do |perm|
          RubyCms::UserPermission.find_or_create_by!(user: user, permission: perm)
        end
      end

      def matching_templates(user)
        user_keys = RubyCms::UserPermission.where(user: user)
                                           .joins(:permission)
                                           .pluck("permissions.key")
        templates.select {|_, tmpl| (tmpl[:keys] - user_keys).empty? }
                 .keys
      end
    end
  end
end
