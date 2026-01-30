# frozen_string_literal: true

module RubyCms
  module Admin
    class SettingsController < BaseController
      before_action { require_permission!(:manage_admin) }

      def index
        @preferences = RubyCms::Preference.order(:category, :key)
        @preference_groups = RubyCms::Preference.by_category
        @active_tab = params[:tab] || "general"
      end

      def update
        key = params[:key]
        value = params[:value]

        RubyCms::Preference.set(key, value)

        respond_to do |format|
          format.html do
            redirect_to ruby_cms_admin_settings_path,
                        notice: t("ruby_cms.admin.settings.updated", key:)
          end
          format.json { render json: { success: true, key: key, value: value } }
        end
      end

      def reset_defaults
        RubyCms::Preference.ensure_defaults!

        redirect_to ruby_cms_admin_settings_path,
                    notice: t("ruby_cms.admin.settings.defaults_reset")
      end
    end
  end
end
