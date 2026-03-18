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
          # Try to render static 404.html, fall back to inline error page
          static_404 = Rails.public_path.join("404.html")
          if static_404.exist?
            render file: static_404, status: :not_found, layout: false
          else
            render_inline_404
          end
        end
        format.json { render json: { error: "Not found" }, status: :not_found }
        format.any { head :not_found }
      end
    end

    private

    def render_inline_404
      escaped_path = ERB::Util.html_escape(request.path.to_s)
      render inline: <<~HTML, status: :not_found, layout: false
        <!DOCTYPE html>
        <html>
        <head>
          <title>Page Not Found (404)</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
              margin: 0;
              padding: 0;
              background: #f5f5f5;
              color: #333;
              display: flex;
              align-items: center;
              justify-content: center;
              min-height: 100vh;
            }
            .error-container {
              text-align: center;
              padding: 40px 20px;
              max-width: 600px;
            }
            h1 {
              font-size: 72px;
              font-weight: 700;
              margin: 0 0 20px;
              color: #dc2626;
            }
            h2 {
              font-size: 24px;
              font-weight: 600;
              margin: 0 0 16px;
              color: #374151;
            }
            p {
              font-size: 16px;
              line-height: 1.6;
              color: #6b7280;
              margin: 0 0 32px;
            }
            a {
              display: inline-block;
              padding: 12px 24px;
              background: #2563eb;
              color: white;
              text-decoration: none;
              border-radius: 6px;
              font-weight: 500;
              transition: background 0.2s;
            }
            a:hover {
              background: #1d4ed8;
            }
            .path {
              font-family: "Monaco", "Courier New", monospace;
              font-size: 14px;
              color: #991b1b;
              background: #fee2e2;
              padding: 8px 12px;
              border-radius: 4px;
              margin: 24px 0;
              word-break: break-all;
            }
          </style>
        </head>
        <body>
          <div class="error-container">
            <h1>404</h1>
            <h2>Page Not Found</h2>
            <p>The page you are looking for doesn't exist or has been moved.</p>
            <div class="path">#{escaped_path}</div>
            <a href="/">Go to Homepage</a>
          </div>
        </body>
        </html>
      HTML
    end
  end
end
