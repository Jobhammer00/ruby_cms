# frozen_string_literal: true

module RubyCms
  module Admin
    class PermissionsController < BaseController
      before_action { require_permission!(:manage_permissions) }

      def index
        @permissions = RubyCms::Permission.order(:key)
      end
    end
  end
end
