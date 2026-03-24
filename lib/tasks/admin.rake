# frozen_string_literal: true

namespace :admin do # rubocop:disable Metrics/BlockLength
  def ruby_cms_user_class
    Object.const_get(Rails.application.config.ruby_cms.user_class_name.presence ||
                        "User")
  end

  def ruby_cms_email_attr(user_class)
    user_class.column_names.include?("email_address") ? :email_address : :email
  end

  def ruby_cms_find_user_by_email(email)
    user_class = ruby_cms_user_class
    email_attr = ruby_cms_email_attr(user_class)
    user_class.find_by(email_attr => email)
  end

  def ruby_cms_make_user_full_admin!(user)
    # Prefer host app's make_admin! if it exists.
    if user.respond_to?(:make_admin!) && user.respond_to?(:admin?) && !user.admin?
      user.make_admin!
    elsif user.class.column_names.include?("admin")
      # Fallback if admin? / make_admin! aren't provided by host app.
      user.update!(admin: true) unless user.respond_to?(:admin?) && user.admin?
    end
  end

  def ruby_cms_grant_all_permissions_to!(user, email:)
    RubyCms::Permission.ensure_defaults!
    RubyCms::UserPermission.where(user:).destroy_all
    RubyCms::Engine.grant_manage_admin_permission(user, email)
  end

  desc "Make a user a full admin with all permissions (no templates). Usage: rails admin:make_admin email=user@example.com"
  task make_admin: :environment do
    email = ENV["email"] || ENV.fetch("EMAIL", nil)
    abort "Usage: rails admin:make_admin email=user@example.com" if email.blank?

    user = ruby_cms_find_user_by_email(email)
    abort "User not found: #{email}" unless user

    ruby_cms_make_user_full_admin!(user)
    ruby_cms_grant_all_permissions_to!(user, email:)

    keys = RubyCms::UserPermission.where(user:)
                                  .joins(:permission)
                                  .pluck("permissions.key")
                                  .sort
                                  .uniq

    puts "#{email} is now admin with #{keys.size} permission(s):"
    keys.each {|k| puts "  - #{k}" }
  end

  desc "List all users with their admin status and permission keys"
  task list_users: :environment do
    user_class = ruby_cms_user_class
    email_attr = ruby_cms_email_attr(user_class)

    users = user_class.order(email_attr)

    if users.none?
      puts "No users found."
      next
    end

    users.each do |user|
      keys = RubyCms::UserPermission.where(user:)
                                    .joins(:permission)
                                    .pluck("permissions.key")
                                    .sort

      admin_flag = user.respond_to?(:admin?) ? user.admin? : false

      puts "#{user.public_send(email_attr)} admin=#{admin_flag} keys=#{keys.join(', ')}"
    end
  end

  desc "Seed all permission keys into the database (no templates)."
  task seed_permissions: :environment do
    RubyCms::Permission.ensure_defaults!
    RubyCms::Settings.ensure_defaults! if defined?(RubyCms::Settings)
    RubyCms::Settings.import_initializer_values! if defined?(RubyCms::Settings)

    puts "Permissions: #{RubyCms::Permission.pluck(:key).sort.join(', ')}"
  end

  desc "Delete admin user. Usage: rails admin:delete email=user@example.com"
  task delete: :environment do
    email = ENV["email"] || ENV.fetch("EMAIL", nil)
    abort "Usage: rails admin:delete email=user@example.com" if email.blank?

    user = ruby_cms_find_user_by_email(email)
    abort "User not found: #{email}" unless user

    print "Delete #{email}? (yes/no): "
    abort "Cancelled." unless $stdin.gets.to_s.strip.downcase == "yes"

    user.destroy!
    puts "Deleted #{email}"
  end

  desc "Log out all users (delete all sessions)"
  task logout_all: :environment do
    abort "Session constant not found in host app. Ensure your auth generator created Session." unless defined?(Session)

    count = Session.count
    if count.zero?
      puts "No active sessions."
      next
    end

    print "Log out all #{count} session(s)? (yes/no): "
    abort "Cancelled." unless $stdin.gets.to_s.strip.downcase == "yes"

    Session.destroy_all
    puts "Logged out #{count} session(s)"
  end
end
