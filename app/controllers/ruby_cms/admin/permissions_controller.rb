# frozen_string_literal: true

module RubyCms
  module Admin
    class PermissionsController < BaseController
      include RubyCms::AdminPagination
      include RubyCms::AdminTurboTable

      paginates per_page: 50, turbo_frame: "admin_table_content"

      before_action { require_permission!(:manage_permissions) }

      def index
        collection = RubyCms::Permission.order(:key)

        # Apply search filter if query parameter is present
        if params[:q].present?
          search_term = "%#{params[:q].downcase}%"
          collection = collection.where("LOWER(key) LIKE ? OR LOWER(name) LIKE ?", search_term, search_term)
        end

        @permissions = paginate_collection(collection)
        # Ensure @permissions is always an iterable collection, never nil
        @permissions ||= RubyCms::Permission.none
      end

      def create
        @permission = RubyCms::Permission.new(permission_params)
        if @permission.save
          redirect_to ruby_cms_admin_permissions_path, notice: "Permission created."
        else
          @permissions = RubyCms::Permission.order(:key)
          flash.now[:alert] =
            "Could not create permission: #{@permission.errors.full_messages.to_sentence}"
          render :index, status: :unprocessable_content
        end
      end

      def destroy
        @permission = RubyCms::Permission.find(params[:id])
        @permission.destroy
        redirect_to ruby_cms_admin_permissions_path, notice: "Permission deleted."
      end

      def bulk_delete
        ids = Array(params[:item_ids]).filter_map(&:to_i)
        permissions = RubyCms::Permission.where(id: ids)
        count = permissions.count
        permissions.destroy_all
        turbo_redirect_to ruby_cms_admin_permissions_path, notice: "#{count} permission(s) deleted."
      end

      private

      def permission_params
        params.expect(permission: %i[key name])
      end
    end
  end
end
