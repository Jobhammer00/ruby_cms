# frozen_string_literal: true

module RubyCms
  module Admin
    class VisualEditorController < BaseController
      before_action { require_permission!(:manage_content_blocks) }

      def index
        @available_pages = available_pages
        requested_page = params[:page].presence
        @current_page =
          if requested_page && @available_pages.key?(requested_page)
            requested_page
          elsif @available_pages.any?
            @available_pages.keys.first
          else
            "home"
          end
        # Enable edit mode by default (can be toggled off)
        @edit_mode = params[:edit_mode].nil? || params[:edit_mode] == "true"
      end

      def page_preview
        @page_key = params[:page] || "home"
        @edit_mode = edit_mode_enabled?
        @content_blocks = load_content_blocks_for_locale
        template = template_for_page(@page_key)

        return render_invalid_page unless template

        load_preview_data(@page_key)
        render template: template, layout: "ruby_cms/minimal"
      end

      def quick_update
        content_block = find_or_initialize_content_block
        update_content_block_attributes(content_block)
        content_block_content(content_block)

        if content_block.save
          render json: success_response(content_block)
        else
          render json: error_response(content_block), status: :unprocessable_content
        end
      end

      private

      def edit_mode_enabled?
        params[:edit_mode].nil? || params[:edit_mode] == "true"
      end

      def current_locale
        params[:locale] || session[:ruby_cms_locale] || I18n.locale.to_s
      end

      def default_locale
        I18n.default_locale.to_s
      rescue StandardError
        "en"
      end

      def load_content_blocks_for_locale
        blocks = ::ContentBlock.all
        blocks_by_locale = blocks.group_by(&:locale)
        locale_blocks = blocks_by_locale[current_locale] || []
        default_blocks = default_locale_blocks(blocks_by_locale)

        content_blocks = {}
        default_blocks&.each {|b| content_blocks[b.key] = b }
        locale_blocks.each {|b| content_blocks[b.key] = b }
        content_blocks
      end

      def default_locale_blocks(blocks_by_locale)
        return nil if current_locale == default_locale

        blocks_by_locale[default_locale] || []
      end

      def render_invalid_page
        all_templates = load_config_templates.merge(auto_detect_templates)
        available_keys = all_templates.keys.join(", ")
        message = if available_keys.present?
                    "Invalid page: #{@page_key}. Available pages: #{available_keys}"
                  else
                    "Invalid page: #{@page_key}. No pages found in app/views. " \
                      "Create a template like app/views/pages/home.html.erb or " \
                      "configure manually in config/initializers/ruby_cms.rb"
                  end
        render plain: message, status: :bad_request
      end

      def find_or_initialize_content_block
        key = params[:key]
        locale = content_block_locale
        ::ContentBlock.find_or_initialize_by(key: key, locale: locale.to_s)
      end

      def content_block_locale
        params[:locale].presence || session[:ruby_cms_locale].presence || I18n.locale.to_s
      end

      def update_content_block_attributes(content_block)
        content_block.content_type = params[:content_type]
        content_block.updated_by = current_user_cms
        content_block.published = true
      end

      def content_block_content(content_block)
        if rich_text_content?
          content_block.rich_content = params[:rich_content]
        elsif params[:content].present?
          content_block.content = params[:content]
        end
      end

      def rich_text_content?
        params[:content_type] == "rich_text" && params[:rich_content].present?
      end

      def success_response(content_block)
        {
          success: true,
          message: "Content updated successfully",
          content: content_block_content_text(content_block),
          rich_content_html: rich_content_html(content_block),
          content_type: content_block.content_type,
          locale: content_block.locale,
          updated_at: formatted_updated_at(content_block)
        }
      end

      def content_block_content_text(content_block)
        if content_block.content_type == "rich_text"
          content_block.rich_content.to_plain_text
        else
          content_block.content
        end
      end

      def rich_content_html(content_block)
        return nil unless content_block.content_type == "rich_text"
        return nil unless content_block.respond_to?(:rich_content)

        content_block.rich_content.to_s
      end

      def formatted_updated_at(content_block)
        content_block.updated_at.strftime("%B %d, %Y at %I:%M %p")
      end

      def error_response(content_block)
        {
          success: false,
          message: content_block.errors.full_messages.join(", ")
        }
      end

      def available_pages
        pages_hash = {}
        add_config_pages(pages_hash)
        add_auto_detected_pages(pages_hash) if pages_hash.empty?
        pages_hash
      end

      def add_auto_detected_pages(pages_hash)
        auto_detect_templates.each do |key, template_path|
          next if pages_hash.key?(key)

          pages_hash[key] = {
            name: key.humanize,
            url: page_url_for(key),
            key_prefix: "#{key}_",
            template_path: template_path
          }
        end
      end

      def page_url_for(key)
        public_page_path(key:)
      rescue NoMethodError, ActionController::UrlGenerationError
        "/p/#{key}"
      end

      def add_config_pages(pages_hash)
        config_pages.each do |key, template_path|
          next if pages_hash.key?(key)

          pages_hash[key] = build_config_page_hash(key, template_path)
        end
      end

      def config_pages
        Rails.application.config.ruby_cms.preview_templates
      rescue StandardError
        {}
      end

      def build_config_page_hash(key, template_path)
        {
          name: key.humanize,
          url: page_url_for(key),
          key_prefix: "#{key}_",
          template_path: template_path
        }
      end

      def add_home_fallback(pages_hash)
        # Don't add home fallback - pages should be configured in the host app
        # via config.ruby_cms.preview_templates
      end

      def home_url
        main_app.root_path
      rescue NoMethodError, ActionController::UrlGenerationError
        "/"
      end

      def template_for_page(page_key)
        template_from_config(page_key) || template_from_auto_detect(page_key)
      end

      def template_from_config(page_key)
        config_templates = load_config_templates
        config_templates[page_key]
      end

      def load_config_templates
        Rails.application.config.ruby_cms.preview_templates
      rescue StandardError
        {}
      end

      def template_from_auto_detect(page_key)
        # Auto-detect templates at runtime if not configured
        detected = auto_detect_templates
        detected[page_key]
      end

      def auto_detect_templates
        @auto_detected_templates ||= detect_templates_at_runtime
      end

      def detect_templates_at_runtime
        views_dir = Rails.root.join("app/views")
        return {} unless Dir.exist?(views_dir)

        templates = {}
        scan_views_for_templates(views_dir, templates)
        templates
      rescue StandardError
        {}
      end

      def scan_views_for_templates(dir_path, templates, relative_path="")
        # Find template files in this directory
        Dir.glob(File.join(dir_path, "*.{html.erb,html.haml,html.slim}")).each do |template_file|
          base_name = File.basename(template_file, ".*")
          base_name = File.basename(base_name, ".*") # Remove .html extension

          # Skip partials and layouts
          next if base_name.start_with?("_")
          next if relative_path == "layouts"
          # Skip admin pages
          next if relative_path.start_with?("admin") || relative_path == "admin"

          # Build template path
          if relative_path.empty?
            template_path = base_name
            page_key = base_name
          elsif base_name == "index"
            page_key = relative_path.split("/").last
            template_path = "#{relative_path}/index"
          else
            page_key = base_name
            template_path = "#{relative_path}/#{base_name}"
          end

          templates[page_key] = template_path unless templates.key?(page_key)
        end

        # Recursively scan subdirectories (skip common non-page dirs, limit depth)
        Dir.glob(File.join(dir_path, "*")).each do |path|
          next unless File.directory?(path)

          dir_name = File.basename(path)
          # Skip admin directories and common non-page directories
          next if %w[layouts shared mailers components admin].include?(dir_name)
          # Skip if we're already in an admin path
          next if relative_path.start_with?("admin")

          depth = relative_path.empty? ? 1 : relative_path.split("/").length + 1
          next if depth > 2

          new_relative_path = relative_path.empty? ? dir_name : "#{relative_path}/#{dir_name}"
          scan_views_for_templates(path, templates, new_relative_path)
        end
      end

      def load_preview_data(page_key)
        # Config-based pages only (existing app templates)
        @page_title = page_key.humanize
      end
    end
  end
end
