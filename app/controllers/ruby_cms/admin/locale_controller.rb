# frozen_string_literal: true

module RubyCms
  module Admin
    class LocaleController < BaseController
      skip_before_action :require_cms_access, only: [:update]
      before_action :ensure_authenticated, only: [:update]

      def update
        locale = params[:locale].to_s.presence&.to_sym
        if I18n.available_locales.include?(locale)
          session[:ruby_cms_locale] = locale
          session[:admin_locale] = locale
          I18n.locale = locale
        end

        redirect_back_or_to(ruby_cms_admin_root_path)
      end
    end
  end
end
