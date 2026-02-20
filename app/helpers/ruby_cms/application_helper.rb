# frozen_string_literal: true

module RubyCms
  module ApplicationHelper
    include RubyCms::Engine.routes.url_helpers if defined?(RubyCms::Engine)

    def ruby_cms_locale_display_name(locale)
      key = "ruby_cms.admin.locales.#{locale}"
      t(key, default: locale.to_s)
    end

    def ruby_cms_user_display(user)
      return "—" if user.blank?

      %i[email_address email username name].each do |attr|
        return user.public_send(attr) if user.respond_to?(attr) && user.public_send(attr).present?
      end
      user.respond_to?(:id) ? "User ##{user.id}" : user.to_s
    end

    def ruby_cms_nav_entries
      RubyCms.visible_nav_registry(
        view_context: self,
        user: (current_user_cms if respond_to?(:current_user_cms))
      )
    end
  end
end
