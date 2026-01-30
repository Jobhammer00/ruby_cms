# frozen_string_literal: true

module RubyCms
  # Tracks security events to Ahoy::Event for analytics and monitoring.
  # Use from host app controllers: RubyCms::SecurityTracker.track(...)
  #
  # Example:
  #   RubyCms::SecurityTracker.track("failed_login", description: "Invalid password", request: request)
  class SecurityTracker
    EVENT_TYPES = %w[
      failed_login
      successful_login
      logout
      admin_access_denied
      suspicious_user_agent
      unusual_request_pattern
      session_hijack_attempt
      rate_limit_exceeded
      csrf_token_mismatch
      unauthorized_admin_attempt
      contact_honeypot_triggered
      contact_blocked_email_attempt
      email_blocklist_error
      ip_blocklist_error
      ip_blocklist_blocked
    ].freeze

    def self.track(event_type, description:, user: nil, request: nil, ip_address: nil,
                   user_agent: nil, request_path: nil)
      return nil unless EVENT_TYPES.include?(event_type)

      attrs = {
        name: event_type,
        ip_address: ip_address || request&.remote_ip,
        request_path: request_path || request&.path,
        user_agent: user_agent || request&.user_agent,
        properties: { description: },
        time: Time.current,
        user: user
      }

      Ahoy::Event.create!(**attrs)
    rescue StandardError => e
      Rails.logger.error "Failed to track security event: #{e.message}"
      nil
    end

    def self.risk_level(event_type)
      case event_type
      when "session_hijack_attempt", "unauthorized_admin_attempt" then "high"
      when "failed_login", "csrf_token_mismatch" then "medium"
      when "successful_login", "logout" then "info"
      else "low"
      end
    end

    def self.risk_color(event_type)
      case risk_level(event_type)
      when "high" then "red"
      when "medium" then "yellow"
      when "info" then "green"
      else "blue"
      end
    end

    def self.formatted_description(event)
      event_type = event.name
      ip = event.ip_address
      user_agent = event.user_agent
      path = event.request_path
      description = event.properties&.dig("description") || event.try(:description)

      case event_type
      when "failed_login" then "Failed login attempt from #{ip}"
      when "successful_login" then "Successful admin login from #{ip}"
      when "logout" then "Admin logout from #{ip}"
      when "admin_access_denied" then "Unauthorized admin access attempt from #{ip}"
      when "unauthorized_admin_attempt" then "Non-admin user attempted admin login"
      when "suspicious_user_agent" then "Suspicious user agent: #{user_agent&.truncate(50)}"
      when "unusual_request_pattern" then "Unusual request pattern: #{path}"
      when "session_hijack_attempt" then "Potential session hijacking from #{ip}"
      when "rate_limit_exceeded" then "Rate limit exceeded from #{ip}"
      when "csrf_token_mismatch" then "CSRF token mismatch on #{path}"
      when "contact_honeypot_triggered" then "Contact honeypot triggered from #{ip}"
      when "contact_blocked_email_attempt" then "Blocked contact email: #{description}"
      when "email_blocklist_error" then "Error adding email to blocklist: #{description}"
      when "ip_blocklist_blocked" then "Blocked IP #{ip} attempting #{path}"
      else description.presence || event_type.humanize
      end
    end
  end
end
