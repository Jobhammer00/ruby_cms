# frozen_string_literal: true

module RubyCms
  # Include in controllers to track page views via Ahoy.
  # Requires the host app to have Ahoy installed (via RubyCMS install generator).
  #
  # Usage:
  #   class PagesController < ApplicationController
  #     include RubyCms::PageTracking
  #   end
  #
  # Sets @page_name to controller_name by default. Override in actions:
  #   @page_name = "custom_page_name"
  #
  module PageTracking
    extend ActiveSupport::Concern

    included do
      before_action :set_page_name
      after_action :track_page_view
    end

    private

    def set_page_name
      @page_name = controller_name if @page_name.blank?
    end

    def track_page_view
      return unless should_track_page_view?

      ahoy.track "page_view",
                 page_name: @page_name,
                 request_path: request.path
    rescue StandardError => e
      Rails.logger.error "[RubyCMS] Failed to track page view: #{e.message}"
    end

    def should_track_page_view?
      # Only track if @page_name is set
      return false if @page_name.blank?

      # Skip admin paths
      return false if request.path.start_with?("/admin")

      # Skip Turbo frame requests (optional - adjust based on needs)
      return false if request.headers["Turbo-Frame"].present?

      true
    end
  end
end
