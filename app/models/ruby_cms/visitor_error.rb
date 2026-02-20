# frozen_string_literal: true

require "uri"

module RubyCms
  class VisitorError < ::ApplicationRecord
    self.table_name = "visitor_errors"

    scope :recent, -> { order(created_at: :desc) }
    scope :unresolved, -> { where(resolved: false) }
    scope :by_page, ->(path) { where(request_path: path) }
    scope :today, -> { where(created_at: Date.current.beginning_of_day..) }

    def self.log_error(exception, request)
      session_id = begin
        request.session.id
      rescue StandardError
        nil
      end
      create!(
        error_class: exception.class.name,
        error_message: exception.message,
        request_path: request.path,
        request_method: request.request_method,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        session_id: session_id,
        referer: request.referer.presence&.truncate(500),
        query_string: request.query_string.presence&.truncate(500),
        backtrace: exception.backtrace&.first(10)&.join("\n"),
        request_params: sanitize_params(request.params)
      )
    rescue StandardError => e
      Rails.logger.error "Failed to log visitor error: #{e.message}"
    end

    # Log routing errors (404s) from catch-all route.
    # Called by RubyCms::ErrorsController#not_found
    def self.log_routing_error(request)
      return if Rails.env.development?
      return if request.path.start_with?("/admin")

      session_id = begin
        request.session.id
      rescue StandardError
        nil
      end
      create!(
        error_class: "ActionController::RoutingError",
        error_message: "No route matches [#{request.request_method}] \"#{request.path}\"",
        request_path: request.path,
        request_method: request.request_method,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        session_id: session_id,
        referer: request.referer.presence&.truncate(500),
        query_string: request.query_string.presence&.truncate(500),
        backtrace: nil,
        request_params: nil
      )
    rescue StandardError => e
      Rails.logger.error "Failed to log routing error: #{e.message}"
    end

    # Returns the code path: backtrace for exceptions, or synthetic path for routing errors
    def codepath
      if backtrace.present?
        backtrace
      elsif error_class == "ActionController::RoutingError"
        <<~TEXT.strip
          Request → Router (no matching route) → RubyCms::ErrorsController#not_found
          (Routing errors don't generate stack traces; the request never reached a controller action.)
        TEXT
      else
        "No stack trace available."
      end
    end

    def browser_info
      return "Unknown" if user_agent.blank?

      case user_agent
      when /Chrome/ then "Chrome"
      when /Firefox/ then "Firefox"
      when /Safari(?!.*Chrome)/ then "Safari"
      when /Edge/ then "Edge"
      else "Other"
      end
    end

    class << self
      private

      def sanitize_params(params)
        return nil unless params

        h = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
        filtered = h.except("password", "password_confirmation", "authenticity_token")
        filtered.to_json.truncate(500)
      end
    end
  end
end
