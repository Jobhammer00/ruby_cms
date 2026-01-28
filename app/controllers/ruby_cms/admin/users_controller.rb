# frozen_string_literal: true

module RubyCms
  module Admin
    class UsersController < BaseController
      include RubyCms::AdminPagination
      include RubyCms::AdminTurboTable

      paginates per_page: 50, turbo_frame: "admin_table_content"

      before_action { require_permission!(:manage_permissions) }

      def index
        collection = user_class.order(:id)

        # Apply search filter if query parameter is present
        if params[:q].present?
          email_attr = user_class.column_names.include?("email_address") ? :email_address : :email
          search_term = "%#{params[:q].downcase}%"
          # Use database-agnostic search
          # For ID search, check if query is numeric and include it
          conditions = ["LOWER(#{email_attr}) LIKE ?"]
          values = [search_term]
          
          if params[:q].match?(/^\d+$/)
            conditions << "id = ?"
            values << params[:q].to_i
          end
          
          collection = collection.where(conditions.join(" OR "), *values)
        end

        @users = paginate_collection(collection)
        # Ensure @users is always an iterable collection, never nil
        @users ||= user_class.none
      end

      def create
        user = user_class.new(user_params)
        if user.save
          redirect_to ruby_cms_admin_users_path, notice: "User created."
        else
          @users = user_class.order(:id).limit(100)
          flash.now[:alert] = "Could not create user: #{user.errors.full_messages.to_sentence}"
          render :index, status: :unprocessable_content
        end
      end

      def destroy
        user = user_class.find(params[:id])
        user.destroy
        redirect_to ruby_cms_admin_users_path, notice: "User deleted."
      end

      def bulk_delete
        ids = Array(params[:item_ids]).filter_map(&:to_i)
        users = user_class.where(id: ids)
        count = users.count
        users.destroy_all
        turbo_redirect_to ruby_cms_admin_users_path, notice: "#{count} user(s) deleted."
      end

      private

      def user_class
        Object.const_get(Rails.application.config.ruby_cms.user_class_name.presence || "User")
      end

      def user_params
        email_attr = user_class.column_names.include?("email_address") ? :email_address : :email
        password_attrs = if user_class.column_names.include?("password")
                           %i[
                             password
                             password_confirmation
                           ]
                         else
                           []
                         end
        params.expect(user: [email_attr, *password_attrs])
      end
    end
  end
end
