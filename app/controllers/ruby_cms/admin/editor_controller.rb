# frozen_string_literal: true

module RubyCms
  module Admin
    class EditorController < BaseController
      before_action { require_permission!(:manage_content_blocks) }

      def index
        @page_keys = preview_templates_keys
        @page_key = params[:page_key].presence || @page_keys.first
        @nonce = SecureRandom.hex(16)
        @content_blocks = RubyCms::ContentBlock.by_key.limit(100)
      end

      def preview
        page_key = params[:page_key].to_s.presence
        templates = preview_templates_hash
        template_path = templates[page_key]

        return render_preview_not_configured if template_path.blank?

        @nonce = params[:nonce].to_s
        return render_bad_request("Invalid preview nonce.") unless valid_preview_nonce?(@nonce)

        @allowed_origin = request.base_url
        assign_preview_data(page_key)

        begin
          render template: template_path, layout: "ruby_cms/editor_preview"
        rescue ActionView::MissingTemplate
          render_missing_template(template_path)
        end
      end

      def bulk
        ids = Array(params[:ids]).map(&:to_i).compact
        action = params[:action_type].to_s

        # Scope to only content blocks accessible by the current user
        content_blocks = RubyCms::ContentBlock.accessible_by(current_user_cms).where(id: ids)

        uid = current_user_cms&.id
        case action
        when "publish"
          content_blocks.update_all(published: true, updated_at: Time.current, updated_by_id: uid)
        when "unpublish"
          content_blocks.update_all(published: false, updated_at: Time.current, updated_by_id: uid)
        else
          head :unprocessable_entity
          return
        end

        redirect_to ruby_cms_admin_editor_path(page_key: params[:page_key]), notice: "Bulk update done."
      end

      private

      def valid_preview_nonce?(nonce)
        nonce.match?(/\A[0-9a-f]{32}\z/)
      end

      def render_preview_not_configured
        html = <<~HTML
          <h1>Preview not configured</h1>
          <p>
            Create a Page (Admin → Pages) with this key, or set
            <code>config.ruby_cms.preview_templates</code> in
            <code>config/initializers/ruby_cms.rb</code>.
          </p>
        HTML

        render html: html.html_safe, status: :not_found, layout: "ruby_cms/editor_preview"
      end

      def render_bad_request(message)
        html = <<~HTML
          <h1>Bad request</h1>
          <p>#{ERB::Util.html_escape(message)}</p>
        HTML

        render html: html.html_safe, status: :bad_request, layout: "ruby_cms/editor_preview"
      end

      def render_missing_template(template_path)
        escaped = ERB::Util.html_escape(template_path.to_s)
        html = <<~HTML
          <h1>Missing template</h1>
          <p>Could not find <code>#{escaped}</code>.</p>
          <p>
            Create it in your app, e.g. <code>app/views/#{escaped}.html.erb</code>,
            or change the page’s <code>template_path</code>.
          </p>
        HTML

        render html: html.html_safe, status: :not_found, layout: "ruby_cms/editor_preview"
      end

      def assign_preview_data(page_key)
        data = (Rails.application.config.ruby_cms.preview_data || ->(*) { {} }).call(page_key, view_context)

        data.each do |k, v|
          name = k.to_s.delete_prefix("@")
          instance_variable_set(:"@#{name}", v)
        end
      end

      def preview_templates_keys
        begin
          RubyCms::Page.all_page_keys
        rescue StandardError
          nil
        end || (Rails.application.config.ruby_cms.preview_templates || {}).keys
      end

      def preview_templates_hash
        begin
          RubyCms::Page.preview_templates_hash
        rescue StandardError
          nil
        end || (Rails.application.config.ruby_cms.preview_templates || {})
      end
    end
  end
end
