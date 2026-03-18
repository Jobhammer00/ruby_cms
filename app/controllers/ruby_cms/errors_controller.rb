# frozen_string_literal: true

module RubyCms
  # Handles 404 errors from catch-all routes.
  # Add this to the BOTTOM of your routes.rb to capture routing errors:
  #
  #   match "*path", to: "ruby_cms/errors#not_found", via: :all,
  #         constraints: ->(req) { !req.path.start_with?("/rails/") }
  #
  class ErrorsController < ApplicationController
    def not_found
      # Log the routing error to VisitorError (skips in development)
      RubyCms::VisitorError.log_routing_error(request)

      respond_to do |format|
        format.html do
          render_html_not_found
        end
        format.json { render json: { error: "Not found" }, status: :not_found }
        format.any { head :not_found }
      end
    end

    private

    def render_html_not_found
      static_not_found = Rails.public_path.join("404.html")
      if static_not_found.exist?
        render file: static_not_found, status: :not_found, layout: false
      else
        render :not_found, status: :not_found, layout: false
      end
    end
  end
end
