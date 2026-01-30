# frozen_string_literal: true

module RubyCms
  # Include in ApplicationController to capture public-site errors to VisitorError.
  # Skips admin controllers (paths under /admin) and development environment by default.
  #
  # Usage in ApplicationController:
  #   include RubyCms::VisitorErrorCapture
  #   rescue_from StandardError, with: :handle_visitor_error
  #
  # Or use the class method to add both:
  #   RubyCms::VisitorErrorCapture.install(self)
  module VisitorErrorCapture
    extend ActiveSupport::Concern

    class_methods do
      def install(controller_class)
        controller_class.include RubyCms::VisitorErrorCapture
        controller_class.rescue_from StandardError, with: :handle_visitor_error
      end
    end

    private

    def handle_visitor_error(exception)
      return if skip_visitor_error_capture?

      RubyCms::VisitorError.log_error(exception, request)
    ensure
      raise exception
    end

    def skip_visitor_error_capture?
      return true if Rails.env.development?

      false
    end
  end
end
