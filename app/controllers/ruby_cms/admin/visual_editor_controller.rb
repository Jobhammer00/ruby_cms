# frozen_string_literal: true

module RubyCms
  module Admin
    class VisualEditorController < BaseController
      before_action { require_permission!(:manage_content_blocks) }
      before_action :apply_visual_editor_locale

      def index
        @available_pages = available_pages
        @current_page = determine_current_page
        @edit_mode = edit_mode_enabled?
      end

      def page_preview
        @page_key = params[:page] || "home"
        @page = @page_key
        @edit_mode = edit_mode_enabled?
        @content_blocks = load_content_blocks_for_locale
        template = template_for_page(@page_key)

        return render_invalid_page unless template

        load_preview_data(@page_key)
        render template: template, layout: "admin/minimal"
      end

      def quick_update
        block = find_or_initialize_content_block
        update_content_block_attributes(block)
        assign_content_block_content(block)

        if block.save
          render json: success_response(block)
        else
          render json: error_response(block), status: :unprocessable_content
        end
      end

      private

      def apply_visual_editor_locale
        requested = params[:locale].presence
        return if requested.blank?

        locale = requested.to_s
        return unless available_locales.include?(locale)

        session[:ruby_cms_locale] = locale
        I18n.locale = locale.to_sym
      end

      def available_locales
        I18n.available_locales.map(&:to_s)
      rescue StandardError
        [I18n.default_locale.to_s]
      end

      def determine_current_page
        requested = params[:page].presence
        return requested if requested && @available_pages.key?(requested)
        return @available_pages.keys.first if @available_pages.any?

        "home"
      end

      def edit_mode_enabled?
        params[:edit_mode].nil? || params[:edit_mode] == "true"
      end

      def template_for_page(page_key)
        template_from_config(page_key) || template_from_auto_detect(page_key)
      end

      def template_from_config(page_key)
        load_config_templates[page_key]
      end

      def template_from_auto_detect(page_key)
        auto_detect_templates[page_key]
      end

      def load_config_templates
        Rails.application.config.ruby_cms.preview_templates
      rescue StandardError
        {}
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

      def find_or_initialize_content_block
        key = params[:key]
        locale = content_block_locale
        ::ContentBlock.find_or_initialize_by(key: key, locale: locale.to_s)
      end

      def content_block_locale
        params[:locale].presence || session[:ruby_cms_locale].presence || I18n.locale.to_s
      end

      def update_content_block_attributes(block)
        block.content_type = params[:content_type]
        block.updated_by = current_user_cms
        block.published = true
      end

      def assign_content_block_content(block)
        if rich_text_content?
          assign_rich_text_content(block)
        elsif params[:content].present?
          block.content = params[:content]
        end
      end

      def assign_rich_text_content(block)
        rich_content = params[:rich_content].to_s

        if block.respond_to?(:rich_content=)
          block.rich_content = rich_content
        else
          block.content = ActionController::Base.helpers.strip_tags(rich_content)
        end
      end

      def rich_text_content?
        params[:content_type] == "rich_text" && params[:rich_content].present?
      end

      def success_response(block)
        {
          success: true,
          message: "Content updated successfully",
          content: content_block_content_text(block),
          rich_content_html: rich_content_html(block),
          content_type: block.content_type,
          locale: block.locale,
          updated_at: formatted_updated_at(block)
        }
      end

      def content_block_content_text(block)
        return block.content unless block.content_type == "rich_text"
        return block.content unless block.respond_to?(:rich_content)
        return block.content unless block.rich_content.respond_to?(:to_plain_text)

        block.rich_content.to_plain_text
      end

      # Return body HTML only (no layout/comments) so preview and Trix get clean HTML.
      def rich_content_html(block)
        return nil unless block.content_type == "rich_text"
        return nil unless block.respond_to?(:rich_content)
        return nil unless block.rich_content.respond_to?(:body) && block.rich_content.body.present?

        body = block.rich_content.body
        body.respond_to?(:to_html) ? body.to_html : body.to_s
      end

      def formatted_updated_at(block)
        block.updated_at.strftime("%B %d, %Y at %I:%M %p")
      end

      def error_response(block)
        {
          success: false,
          message: block.errors.full_messages.join(", ")
        }
      end

      def available_pages
        pages = {}
        add_config_pages(pages)
        add_auto_detected_pages(pages) if pages.empty?
        prioritize_home_page(pages)
      end

      def prioritize_home_page(pages)
        return pages unless pages.key?("home")

        { "home" => pages["home"] }.merge(pages.except("home"))
      end

      def add_auto_detected_pages(pages)
        auto_detect_templates.each do |key, template_path|
          next if pages.key?(key)

          pages[key] = build_page_hash(key, template_path)
        end
      end

      def add_config_pages(pages)
        config_pages.each do |key, template_path|
          pages[key] ||= build_page_hash(key, template_path)
        end
      end

      def build_page_hash(key, template_path)
        {
          name: key.humanize,
          url: page_url_for(key),
          key_prefix: "#{key}_",
          template_path: template_path
        }
      end

      def config_pages
        Rails.application.config.ruby_cms.preview_templates
      rescue StandardError
        {}
      end

      def page_url_for(key)
        public_page_path(key:)
      rescue NoMethodError, ActionController::UrlGenerationError
        "/p/#{key}"
      end

      def current_locale
        (params[:locale] || session[:ruby_cms_locale] || I18n.locale.to_s).to_s
      end

      def default_locale
        I18n.default_locale.to_s
      rescue StandardError
        "en"
      end

      def auto_detect_templates
        @auto_detect_templates ||= detect_templates_at_runtime
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
        Dir.glob(File.join(dir_path, "*")).each do |path|
          if File.directory?(path)
            scan_subdirectory(path, templates, relative_path)
          else
            process_template_file(path, templates, relative_path)
          end
        end
      end

      def scan_subdirectory(path, templates, relative_path)
        dir_name = File.basename(path)
        return if skip_directory?(dir_name, relative_path)

        new_relative_path = relative_path.empty? ? dir_name : "#{relative_path}/#{dir_name}"
        return if depth_exceeded?(new_relative_path)

        scan_views_for_templates(path, templates, new_relative_path)
      end

      def skip_directory?(dir_name, relative_path)
        %w[
          layouts shared mailers components
          admin
        ].include?(dir_name) ||
          dir_name.end_with?("_mailer") ||
          dir_name.end_with?("_mailers") ||
          relative_path.start_with?("admin")
      end

      def depth_exceeded?(relative_path)
        relative_path.split("/").length > 2
      end

      def process_template_file(file_path, templates, relative_path)
        return unless file_path.match?(/\.(html\.erb|html\.haml|html\.slim)$/)

        base_name = File.basename(file_path, ".*").sub(/\.html$/, "")
        if base_name.start_with?("_") || relative_path == "layouts" ||
           relative_path.start_with?("admin")
          return
        end

        page_key, template_path = build_page_key_and_template_path(base_name, relative_path)
        templates[page_key] ||= template_path
      end

      def build_page_key_and_template_path(base_name, relative_path)
        if relative_path.empty?
          [base_name, base_name]
        elsif base_name == "index"
          key = relative_path.split("/").last
          [key, "#{relative_path}/index"]
        else
          [base_name, "#{relative_path}/#{base_name}"]
        end
      end

      def load_preview_data(page_key)
        @page_title = page_key.humanize

        data_proc = Rails.application.config.ruby_cms.preview_data
        return unless data_proc.respond_to?(:call)

        data = data_proc.call(page_key, view_context)
        return unless data.kind_of?(Hash)

        data.each do |k, v|
          instance_variable_set(:"@#{k}", v)
        end
      end
    end
  end
end
