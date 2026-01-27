# frozen_string_literal: true

module RubyCms
  module Admin
    class VisualEditorController < BaseController
      before_action { require_permission!(:manage_content_blocks) }

      def index
        @current_page = params[:page] || "home"
        @available_pages = get_available_pages
        # Enable edit mode by default (can be toggled off)
        @edit_mode = params[:edit_mode].nil? || params[:edit_mode] == "true"
      end

      def page_preview
        @page_key = params[:page] || "home"
        # Enable edit mode by default (can be toggled off)
        @edit_mode = params[:edit_mode].nil? || params[:edit_mode] == "true"

        # Get current locale (from session or params)
        current_locale = params[:locale] || session[:ruby_cms_locale] || I18n.locale.to_s

        # Load all content blocks for current locale (and default locale as fallback)
        # Index by key for quick lookup, prioritizing current locale
        blocks = RubyCms::ContentBlock.all
        default_locale = begin
          I18n.default_locale.to_s
        rescue StandardError
          "en"
        end

        # Group by locale, then merge with current locale taking priority
        blocks_by_locale = blocks.group_by(&:locale)
        current_locale_blocks = blocks_by_locale[current_locale] || []
        if current_locale != default_locale
          default_locale_blocks = blocks_by_locale[default_locale] || []
        end

        # Index by key, current locale first, then default locale as fallback
        @content_blocks = {}
        default_locale_blocks&.each {|b| @content_blocks[b.key] = b }
        current_locale_blocks.each {|b| @content_blocks[b.key] = b }

        # Load page from database if it exists
        @page = RubyCms::Page.find_by(key: @page_key)

        # Get the template to render
        template = get_template_for_page(@page_key)

        if template.nil?
          render plain: "Invalid page: #{@page_key}", status: :bad_request
          return
        end

        # Load preview data if needed
        load_preview_data(@page_key)

        # Always use minimal layout for visual editor preview
        # This ensures consistent editing experience regardless of page layout
        render template: template, layout: "ruby_cms/minimal"
      end

      def quick_update
        key = params[:key]
        # Use locale from params, session, or current I18n locale
        locale = params[:locale].presence || session[:ruby_cms_locale].presence || I18n.locale.to_s

        # Try to find existing block for this locale, or create new one
        content_block = RubyCms::ContentBlock.find_or_initialize_by(key: key, locale: locale.to_s)

        content_block.content_type = params[:content_type]
        content_block.updated_by = current_user_cms
        # Auto-publish content blocks saved from visual editor
        content_block.published = true

        # Handle rich_text separately from regular content
        if params[:content_type] == "rich_text" && params[:rich_content].present?
          content_block.rich_content = params[:rich_content]
        elsif params[:content].present?
          content_block.content = params[:content]
        end

        if content_block.save
          render json: {
            success: true,
            message: "Content updated successfully",
            content: content_block.content_type == "rich_text" ? content_block.rich_content.to_plain_text : content_block.content,
            rich_content_html: content_block.content_type == "rich_text" && content_block.respond_to?(:rich_content) ? content_block.rich_content.to_s : nil,
            content_type: content_block.content_type,
            locale: content_block.locale,
            updated_at: content_block.updated_at.strftime("%B %d, %Y at %I:%M %p")
          }
        else
          render json: {
            success: false,
            message: content_block.errors.full_messages.join(", ")
          }, status: :unprocessable_content
        end
      end

      private

      def get_available_pages
        pages_hash = {}

        # Load all pages from database
        RubyCms::Page.order(:position, :key).each do |page|
          # Generate URL for the page
          page_url = begin
            public_page_path(key: page.key)
          rescue NoMethodError, ActionController::UrlGenerationError
            "/p/#{page.key}"
          end

          pages_hash[page.key] = {
            name: page.title.presence || page.key.humanize,
            url: page_url,
            key_prefix: "#{page.key}_",
            render_mode: page.render_mode,
            page_id: page.id
          }
        end

        # Also include config-based pages (for backwards compatibility)
        config_pages = begin
          Rails.application.config.ruby_cms.preview_templates
        rescue StandardError
          {}
        end || {}

        config_pages.each do |key, template_path|
          next if pages_hash.key?(key) # Skip if already in DB

          page_url = begin
            public_page_path(key:)
          rescue NoMethodError, ActionController::UrlGenerationError
            "/p/#{key}"
          end

          pages_hash[key] = {
            name: key.humanize,
            url: page_url,
            key_prefix: "#{key}_",
            render_mode: "template",
            template_path: template_path
          }
        end

        # Fallback to "home" if no pages exist
        if pages_hash.empty?
          home_url = begin
            main_app.root_path
          rescue NoMethodError, ActionController::UrlGenerationError
            "/"
          end

          pages_hash["home"] = {
            name: "Homepage",
            url: home_url,
            key_prefix: "home_",
            render_mode: "template"
          }
        end

        pages_hash
      end

      def get_template_for_page(page_key)
        # First try to find page in database
        page = RubyCms::Page.find_by(key: page_key)

        if page
          case page.render_mode
          when "template"
            page.template_path
          when "builder", "html"
            # Use the show template which handles builder/html rendering
            "ruby_cms/public/pages/show"
          else
            nil
          end
        else
          # Fallback to config-based templates
          config_templates = begin
            Rails.application.config.ruby_cms.preview_templates
          rescue StandardError
            {}
          end || {}

          config_templates[page_key] || (page_key == "home" ? "ruby_cms/public/pages/home" : nil)
        end
      end

      def load_preview_data(page_key)
        # Load page from database if it exists
        @page = RubyCms::Page.find_by(key: page_key)

        if @page
          @page_title = @page.title.presence || @page.key.humanize

          # For builder/html modes, we need to load the page data
          if @page.builder_mode? || @page.html_mode?
            # The show template will handle rendering
            @render_mode = @page.render_mode
          end
        else
          # Fallback for config-based pages
          @page_title = page_key.humanize
        end
      end
    end
  end
end
