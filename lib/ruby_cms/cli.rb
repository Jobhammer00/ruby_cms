# frozen_string_literal: true

require "thor"

module RubyCms
  class CLI < Thor
    default_task :setup_admin

    desc "setup_admin",
         "Interactively create or select the first admin user and grant full permissions"
    def setup_admin
      RunSetupAdmin.call(shell:)
    end

    private

    def shell
      @shell ||= Thor::Shell::Basic.new
    end
  end

  # Logic for the interactive first-admin setup. Uses Thor::Shell for prompts.
  class RunSetupAdmin
    ADMIN_PERMISSION_KEYS = %w[
      manage_admin manage_permissions manage_content_blocks manage_pages
      publish_pages
    ].freeze

    class << self
      def call(shell: Thor::Shell::Basic.new)
        new(shell:).call
      end
    end

    def initialize(shell:)
      @shell = shell
    end

    def call
      RubyCms::Permission.ensure_defaults!
      user_class = Rails.application.config.ruby_cms.user_class_name.constantize
      email_attr = user_class.column_names.include?("email_address") ? :email_address : :email

      user = choose_or_create_user(user_class, email_attr)
      return if user.nil?

      grant_permissions(user)
      @shell.say(
        "\nDone. #{user.public_send(email_attr)} now has: #{ADMIN_PERMISSION_KEYS.join(', ')}.", :green
      )
      @shell.say("Visit /admin to sign in.", :green)
    end

    private

    def choose_or_create_user(user_class, email_attr)
      users = user_class.order(id: :asc).limit(20).to_a

      if users.any?
        @shell.say("\nExisting users:", :bold)
        users.each_with_index do |u, i|
          @shell.say("  #{i + 1}. #{u.public_send(email_attr)}")
        end
        @shell.say("  0. Enter another email (or create new user)")
        choice = @shell.ask("Select (0–#{users.size}):", default: "1").to_s.strip

        if choice == "0"
          find_or_create_by_email(user_class, email_attr)
        else
          idx = choice.to_i
          if idx.between?(1,
                          users.size)
            users[idx - 1]
          else
            find_or_create_by_email(user_class,
                                    email_attr)
          end
        end
      else
        @shell.say("\nNo users yet. Create the first admin user.")
        create_user(user_class, email_attr)
      end
    end

    def find_or_create_by_email(user_class, email_attr)
      email = @shell.ask("Email:").to_s.strip
      return nil if email.blank?

      user = user_class.find_by(email_attr => email)
      if user
        user
      else
        @shell.say("User not found.")
        create = @shell.yes?("Create new user with this email?", default: true)
        create ? create_user_with_email(user_class, email_attr, email) : nil
      end
    end

    def create_user(user_class, email_attr)
      email = @shell.ask("Email:").to_s.strip
      return nil if email.blank?

      create_user_with_email(user_class, email_attr, email)
    end

    def create_user_with_email(user_class, email_attr, email)
      password = ask_password("Password:")
      return nil if password.blank?

      password_confirmation = ask_password("Password (again):")
      if password != password_confirmation
        @shell.say("Passwords did not match. Aborted.", :red)
        return nil
      end

      attrs = {
        email_attr => email, password: password,
        password_confirmation: password_confirmation
      }
      user_class.create!(attrs)
    rescue ActiveRecord::RecordInvalid => e
      @shell.say("Could not create user: #{e.record.errors.full_messages.to_sentence}", :red)
      nil
    end

    def ask_password(prompt)
      if $stdin.respond_to?(:noecho) && $stdin.tty?
        @shell.say("#{prompt} (hidden)")
        $stdin.noecho { $stdin.gets&.chomp }.to_s
      else
        @shell.ask("#{prompt}:").to_s.strip
      end
    end

    def grant_permissions(user)
      ADMIN_PERMISSION_KEYS.each do |key|
        perm = RubyCms::Permission.find_by!(key:)
        RubyCms::UserPermission.find_or_create_by!(user: user, permission: perm)
      end
    end
  end
end
