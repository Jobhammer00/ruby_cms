# frozen_string_literal: true

module RubyCms
  module Public
    # Renders a CMS page by key: finds Page, renders based on render_mode.
    # Route: GET /p/:key. Uses config.ruby_cms.public_page_layout (default "application").
    class PagesController < ActionController::Base
      helper RubyCms::PageRendererHelper

      def show
        # Try to find page in DB first
        @page = RubyCms::Page.published_only.find_by(key: params[:key])

        if @page
          # Set HTTP caching headers - returns true if fresh (304 response sent)
          return if set_cache_headers

          render_db_page
        else
          render_code_page
        end
      rescue ActionView::MissingTemplate => e
        handle_missing_template(e)
      end

      private

      def render_db_page
        case @page.render_mode
        when "template"
          # Use page's layout if specified, otherwise config default
          self.class.layout(@page.effective_layout)
          render template: @page.template_path
        when "builder", "html"
          # Use page's layout if specified, otherwise config default
          self.class.layout(@page.effective_layout)
          
          # Use compiled HTML if available and fresh
          if @page.compiled_html_fresh? && @page.compiled_html.present?
            render html: @page.compiled_html.html_safe, layout: @page.effective_layout
          else
            render template: "ruby_cms/public/pages/show"
          end
        else
          render html: "<h1>Invalid render mode</h1><p>Page has invalid render_mode: #{ERB::Util.html_escape(@page.render_mode)}</p>".html_safe,
                 status: :internal_server_error, layout: false
        end
      end

      def render_code_page
        # Fallback to codebase pages via config
        public_templates = begin
          Rails.application.config.ruby_cms.public_templates
        rescue StandardError
          nil
        end ||
                           begin
                             Rails.application.config.ruby_cms.preview_templates
                           rescue StandardError
                             nil
                           end ||
                           {}

        template_path = public_templates[params[:key].to_s]

        if template_path
          self.class.layout(begin
            Rails.application.config.ruby_cms.public_page_layout
          rescue StandardError
            nil
          end.presence || "application")
          render template: template_path
        else
          render html: "<h1>Not found</h1><p>Page \"#{ERB::Util.html_escape(params[:key])}\" does not exist or is not published.</p>".html_safe,
                 status: :not_found, layout: false
        end
      end

      def handle_missing_template(_error)
        escaped = ERB::Util.html_escape(@page&.template_path.to_s)
        render html: "<h1>Missing template</h1>" \
          "<p>Could not find <code>#{escaped}</code>.</p>" \
          "<p>Create it in your app, e.g. <code>app/views/#{escaped}.html.erb</code>, " \
          "or change the page's <code>template_path</code>.</p>".html_safe, status: :not_found, layout: false
      end

      def set_cache_headers
        return false unless @page

        # Use ETag based on page updated_at and compiled_at
        etag_value = [
          @page.updated_at.to_i,
          @page.compiled_at.to_i,
          @page.id
        ].join("-")

        # Set cache control headers (public, max-age, stale-while-revalidate)
        response.headers["Cache-Control"] = "public, max-age=3600, stale-while-revalidate=86400"

        # Set Vary header to ensure proper cache key generation
        response.headers["Vary"] = "Accept-Encoding"

        # Check freshness - returns true if client cache is fresh (304 sent)
        fresh_when(etag: etag_value, last_modified: @page.updated_at)
      end
    end
  end
end
