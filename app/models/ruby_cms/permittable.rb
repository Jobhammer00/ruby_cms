# frozen_string_literal: true

module RubyCms
  module Permittable
    extend ActiveSupport::Concern

    # Check if the user has a permission. record: reserved for future record-scoped permissions.
    # Default-deny: unknown permission key = forbidden. Permission lookups are cached per-request.
    def can?(permission_key, record: nil)
      return bootstrap_allowed?(permission_key) if bootstrap?

      k = permission_key.to_s
      return false unless RubyCms::Permission.exists?(key: k)

      cms_permission_keys_cached.include?(k) ||
        record&.can_edit?(self)
    end

    def bootstrap?
      RubyCms::Permission.none?
    end

    def bootstrap_allowed?(permission_key)
      return false unless Rails.application.config.ruby_cms.bootstrap_admin_with_role
      return false unless respond_to?(:admin?) && admin?

      permission_key.to_s == "manage_admin"
    end

    # Per-request cache of this user's permission keys. Never rely on client-side checks.
    def cms_permission_keys_cached
      @cms_permission_keys_cached ||=
        RubyCms::UserPermission.where(user: self)
                               .joins(:permission).pluck("permissions.key")
    end
  end
end
