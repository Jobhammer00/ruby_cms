# frozen_string_literal: true

module RubyCms
  module Admin
    class UserPermissionsController < BaseController
      before_action { require_permission!(:manage_permissions) }
      before_action :set_user

      def index
        @permissions = RubyCms::Permission.order(:key)
        @user_permissions = if @user
                              RubyCms::UserPermission.where(user: @user)
                                                     .includes(:permission)
                            else
                              []
                            end
      end

      def create
        if params[:template].present?
          apply_template
        else
          grant_individual_permission
        end
      end

      def destroy
        up = RubyCms::UserPermission.find_by!(user: @user, id: params[:id])
        up.destroy
        redirect_to ruby_cms_admin_user_permissions_path(@user),
                    notice: t("ruby_cms.admin.user_permissions.revoked")
      end

      def bulk_delete
        ids = Array(params[:item_ids]).filter_map(&:to_i)
        user_permissions = RubyCms::UserPermission.where(user: @user, id: ids)
        count = user_permissions.count
        user_permissions.destroy_all
        redirect_to ruby_cms_admin_user_permissions_path(@user),
                    notice: "#{count} permission(s) #{
                      t('ruby_cms.admin.user_permissions.revoked')
                    }."
      end

      private

      def set_user
        @user = user_class.find(params[:user_id])
      end

      def user_class
        Object.const_get(Rails.application.config.ruby_cms.user_class_name.presence || "User")
      end

      def apply_template
        template_key = params[:template].to_sym
        RubyCms::UserPermission.where(user: @user).destroy_all
        RubyCms::Permission.apply_template!(@user, template_key)
        @user.make_admin! if @user.respond_to?(:make_admin!) && !@user.admin?
        redirect_to ruby_cms_admin_user_permissions_path(@user),
                    notice: "Applied #{RubyCms::Permission.templates.dig(template_key, :label)} template."
      rescue ArgumentError => e
        redirect_to ruby_cms_admin_user_permissions_path(@user), alert: e.message
      end

      def grant_individual_permission
        permission = RubyCms::Permission.find(params[:permission_id])
        RubyCms::UserPermission.find_or_create_by!(user: @user, permission: permission)
        redirect_to ruby_cms_admin_user_permissions_path(@user),
                    notice: t("ruby_cms.admin.user_permissions.granted")
      rescue ActiveRecord::RecordInvalid
        redirect_to ruby_cms_admin_user_permissions_path(@user),
                    alert: t("ruby_cms.admin.user_permissions.could_not_grant")
      end
    end
  end
end
