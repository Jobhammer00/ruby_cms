# frozen_string_literal: true

module RubyCms
  module AdminTurboTable
    extend ActiveSupport::Concern

    # Check if this is a Turbo Frame request
    # @return [Boolean]
    def turbo_frame_request?
      request.headers["Turbo-Frame"].present?
    end

    # Render index action with Turbo Frame support
    # If Turbo Frame request, renders only the table content
    # Otherwise renders full page
    # @param turbo_frame_id [String] Turbo Frame ID (default: "admin_table_content")
    def turbo_render_index(turbo_frame_id: "admin_table_content")
      if turbo_frame_request?
        render partial: turbo_frame_id, layout: false
      else
        render :index
      end
    end

    # Redirect with Turbo Frame support
    # If Turbo Frame request, renders Turbo Stream redirect
    # Otherwise performs normal redirect
    # @param url [String] URL to redirect to
    # @param options [Hash] Redirect options (notice, alert, etc.)
    def turbo_redirect_to(url, **)
      if turbo_frame_request?
        # For Turbo Frame requests, we can't redirect directly
        # Instead, we should render a Turbo Stream that updates the frame
        # or redirect the parent window
        redirect_to(url, **)
      else
        redirect_to(url, **)
      end
    end

    # Get Turbo Frame ID from request
    # @return [String, nil]
    def turbo_frame_id
      request.headers["Turbo-Frame"]
    end

    # Check if request expects Turbo Stream response
    # @return [Boolean]
    def turbo_stream_request?
      request.headers["Accept"]&.include?("text/vnd.turbo-stream.html")
    end

    # Render Turbo Stream update for table
    # @param turbo_frame_id [String] Turbo Frame ID
    # @param partial [String] Partial to render (default: turbo_frame_id)
    def turbo_stream_update_table(turbo_frame_id: "admin_table_content", partial: nil)
      partial ||= turbo_frame_id
      render turbo_stream: turbo_stream.update(turbo_frame_id, partial:)
    end

    # Render Turbo Stream replace for table
    # @param turbo_frame_id [String] Turbo Frame ID
    # @param partial [String] Partial to render (default: turbo_frame_id)
    def turbo_stream_replace_table(turbo_frame_id: "admin_table_content", partial: nil)
      partial ||= turbo_frame_id
      render turbo_stream: turbo_stream.replace(turbo_frame_id, partial:)
    end
  end
end
