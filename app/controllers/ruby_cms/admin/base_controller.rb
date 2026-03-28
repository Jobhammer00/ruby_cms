# frozen_string_literal: true

module RubyCms
  module Admin
    # Base for all /admin controllers. Ensures authentication and permission enforcement.
    # Inherits from the host's ApplicationController (or config.admin_base_controller).
    # This layout must not be used for public pages.
    class BaseController < Rails.application.config.ruby_cms.admin_base_controller.constantize
      layout -> { Rails.application.config.ruby_cms.admin_layout.presence || "admin/admin" }
      before_action :set_cms_locale
      before_action :require_cms_access

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

      helper_method :current_user_cms, :require_permission!

      # Expose the engine's route helpers (ruby_cms_admin_*_path) in controllers.
      # The host's _routes does not expose the mounted engine's named routes to
      # the engine's own controllers; we keep _routes as the host's for
      # new_session_path, root_path, etc.
      include RubyCms::Engine.routes.url_helpers

      # Public API: dashboard block +data procs and host code may call this on the controller instance.
      def current_user_cms
        @current_user_cms ||= resolve_current_user
      end

      private

      def resolve_current_user
        if respond_to?(:current_user, true)
          send(:current_user)
        else
          Rails.application.config.ruby_cms.current_user_resolver&.call(self)
        end
      end

      def require_cms_access
        ensure_authenticated
        require_permission!(:manage_admin)
      end

      def ensure_authenticated
        return if current_user_cms

        if respond_to?(:require_authentication, true)
          send(:require_authentication)
        else
          redirect_to cms_redirect_path, alert: t("ruby_cms.admin.base.authentication_required")
        end
      end

      # Forbid (403) or redirect with flash. Default-deny: unknown permission = forbidden.
      def require_permission!(permission_key, record: nil)
        return if current_user_cms&.can?(permission_key, record:)

        respond_to do |format|
          format.html do
            redirect_to(cms_redirect_path, alert: t("ruby_cms.admin.base.not_authorized"))
          end
          format.any { head :forbidden }
        end
      end

      # Optional role gate. Example: before_action { require_role!(:admin) } in a subclass.
      # Uses user.admin? when role is :admin (if the host's User responds to :admin?).
      def require_role!(role)
        return if current_user_cms.nil?
        return if role == :admin && current_user_cms.respond_to?(:admin?) && current_user_cms.admin?

        respond_to do |format|
          format.html do
            redirect_to cms_redirect_path, alert: t("ruby_cms.admin.base.not_authorized")
          end
          format.any { head :forbidden }
        end
      end

      def cms_redirect_path
        Rails.application.config.ruby_cms.unauthorized_redirect_path.presence || "/"
      end

      def render_not_found
        render "ruby_cms/errors/not_found",
               status: :not_found,
               layout: Rails.application.config.ruby_cms.admin_layout.presence || "admin/admin"
      end

      def set_cms_locale
        locale = session[:ruby_cms_locale].presence || session[:admin_locale].presence
        return if locale.blank?

        locale = locale.to_sym
        return unless I18n.available_locales.include?(locale)

        # Keep both session keys in sync for host app + engine controllers.
        session[:ruby_cms_locale] = locale
        session[:admin_locale] = locale
        I18n.locale = locale
      end

      # Resolve parameter key for model params
      # Checks if a specific key exists in params, otherwise falls back to model's param_key
      # @param model_class [Class] The model class (e.g., ContentBlock)
      # @param param_name [Symbol] The expected parameter name (e.g., :page)
      # @return [Symbol] The resolved parameter key
      def model_param_key(model_class, param_name)
        params.key?(param_name) ? param_name : model_class.model_name.param_key.to_sym
      end

      public :current_user_cms
    end
  end
end
