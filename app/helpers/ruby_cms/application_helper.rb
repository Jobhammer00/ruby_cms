# frozen_string_literal: true

module RubyCms
  module ApplicationHelper
    # Expose the engine's route helpers (ruby_cms_admin_*_path) in views.
    include RubyCms::Engine.routes.url_helpers

    def ruby_cms_locale_display_name(locale)
      key = "ruby_cms.admin.locales.#{locale}"
      t(key, default: locale.to_s)
    end

    # Display a user for admin views. Tries common attributes (email, email_address,
    # username, name) since host apps may use different User models.
    def ruby_cms_user_display(user)
      return "—" if user.blank?

      %i[email_address email username name].each do |attr|
        return user.public_send(attr) if user.respond_to?(attr) && user.public_send(attr).present?
      end
      user.respond_to?(:id) ? "User ##{user.id}" : user.to_s
    end

    def ruby_cms_nav_entries
      RubyCms.visible_nav_registry.select do |e|
        next false if e[:if].present? && (!e[:if].respond_to?(:call) || !e[:if].call(self))

        true
      end
    end
  end
end
