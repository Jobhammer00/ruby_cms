# frozen_string_literal: true

module RubyCms
  module Admin
    class UsersController < BaseController
      include RubyCms::AdminPagination
      include RubyCms::AdminTurboTable

      paginates per_page: 50, turbo_frame: "admin_table_content"

      before_action { require_permission!(:manage_permissions) }

      def index
        @users = paginated_users
        @index ||= user_class.none
      end

      def create
        user = user_class.new(user_params)
        if user.save
          redirect_to ruby_cms_admin_users_path, notice: t("ruby_cms.admin.users.created")
        else
          handle_create_failure(user)
        end
      end

      def destroy
        user = user_class.find(params[:id])
        user.destroy
        redirect_to ruby_cms_admin_users_path, notice: t("ruby_cms.admin.users.deleted")
      end

      def bulk_delete
        ids = Array(params[:item_ids]).filter_map(&:to_i)
        users = user_class.where(id: ids)
        count = users.count
        users.destroy_all
        turbo_redirect_to ruby_cms_admin_users_path, notice: "#{count} user(s) #{
          t('ruby_cms.admin.users.deleted')
        }."
      end

      private

      def paginated_users
        collection = user_class.order(:id)
        collection = apply_search_filter(collection)
        paginate_collection(collection)
      end

      def apply_search_filter(collection)
        return collection if params[:q].blank?

        collection.where(build_search_conditions)
      end

      def build_search_conditions
        search_term = "%#{params[:q].downcase}%"
        email_attr = user_email_column
        conditions = ["LOWER(#{email_attr}) LIKE ?"]
        values = [search_term]

        if numeric_query?
          conditions << "id = ?"
          values << params[:q].to_i
        end

        [conditions.join(" OR "), *values]
      end

      def user_email_column
        user_class.column_names.include?("email_address") ? :email_address : :email
      end

      def numeric_query?
        params[:q] =~ /^\d+$/
      end

      def handle_create_failure(user)
        @users = user_class.order(:id).limit(100)
        flash.now[:alert] = t(
          "ruby_cms.admin.users.could_not_create",
          errors: user.errors.full_messages.to_sentence
        )
        render :index, status: :unprocessable_content
      end

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
