# frozen_string_literal: true

module RubyCms
  module Admin
    class UserPermissionsController < BaseController
      before_action { require_permission!(:manage_permissions) }
      before_action :set_user

      def index
        @permissions = RubyCms::Permission.order(:key)
        @user_permissions = @user ? RubyCms::UserPermission.where(user: @user).includes(:permission) : []
      end

      def create
        permission = RubyCms::Permission.find(params[:permission_id])
        if RubyCms::UserPermission.find_or_create_by!(user: @user, permission: permission)
          redirect_to ruby_cms_admin_user_permissions_path(@user), notice: "Permission granted."
        end
      rescue ActiveRecord::RecordInvalid
        redirect_to ruby_cms_admin_user_permissions_path(@user),
                    alert: "Could not grant permission."
      end

      def destroy
        up = RubyCms::UserPermission.find_by!(user: @user, id: params[:id])
        up.destroy
        redirect_to ruby_cms_admin_user_permissions_path(@user), notice: "Permission revoked."
      end

      def bulk_delete
        ids = Array(params[:item_ids]).filter_map(&:to_i)
        user_permissions = RubyCms::UserPermission.where(user: @user, id: ids)
        count = user_permissions.count
        user_permissions.destroy_all
        redirect_to ruby_cms_admin_user_permissions_path(@user),
                    notice: "#{count} permission(s) revoked."
      end

      private

      def set_user
        @user = user_class.find(params[:user_id])
      end

      def user_class
        Object.const_get(Rails.application.config.ruby_cms.user_class_name.presence || "User")
      end
    end
  end
end
