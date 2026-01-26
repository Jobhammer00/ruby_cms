# frozen_string_literal: true

module RubyCms
  module Admin
    class UsersController < BaseController
      before_action { require_permission!(:manage_permissions) }

      def index
        @users = user_class.order(:id).limit(100)
      end

      private

      def user_class
        Object.const_get(Rails.application.config.ruby_cms.user_class_name.presence || "User")
      end
    end
  end
end
