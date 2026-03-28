# frozen_string_literal: true

module RubyCms
  module EngineAdminPermissions
    def grant_admin_permissions_to_admin_users
      return unless defined?(::User) && User.column_names.include?("admin")

      permission_keys = RubyCms::Permission.all_keys
      permissions = RubyCms::Permission.where(key: permission_keys).index_by(&:key)
      User.where(admin: true).find_each do |u|
        permission_keys.each do |key|
          perm = permissions[key]
          next if perm.nil?

          RubyCms::UserPermission.find_or_create_by!(user: u, permission: perm)
        end
      end
    end

    def extract_email_from_args(args)
      args[:email] || ENV["email"] || ENV.fetch("EMAIL", nil)
    end

    def validate_email_present(email)
      return if email.present?

      warn "Usage: rails ruby_cms:grant_manage_admin " \
           "email=user@example.com"
      raise "Email is required"
    end

    def find_user_by_email(email)
      user_class = Rails.application.config.ruby_cms.user_class_name
                        .constantize
      find_user_by_email_address(user_class, email) ||
        find_user_by_email_column(user_class, email)
    end

    def find_user_by_email_address(user_class, email)
      return unless user_class.column_names.include?("email_address")

      user_class.find_by(email_address: email)
    end

    def find_user_by_email_column(user_class, email)
      return unless user_class.column_names.include?("email")

      user_class.find_by(email:)
    end

    def validate_user_found(user, email)
      return if user

      warn "User not found: #{email}"
      raise "User not found: #{email}"
    end

    def grant_manage_admin_permission(user, email)
      RubyCms::Permission.ensure_defaults!
      RubyCms::Permission.all_keys.each do |key|
        perm = RubyCms::Permission.find_by(key:)
        next unless perm

        RubyCms::UserPermission.find_or_create_by!(user: user, permission: perm)
      end
      puts "Granted full admin permissions to #{email}" # rubocop:disable Rails/Output
    end
  end
end
