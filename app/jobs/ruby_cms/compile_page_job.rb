# frozen_string_literal: true

module RubyCms
  class CompilePageJob < ActiveJob::Base
    queue_as :default

    def perform(page_id)
      page = RubyCms::Page.find_by(id: page_id)
      unless page
        Rails.logger.warn "CompilePageJob: Page #{page_id} not found" if defined?(Rails.logger)
        return
      end

      # Only compile builder and html modes
      return unless page.builder_mode? || page.html_mode?

      # Create a view context for rendering
      view = ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil)
      view.extend(RubyCms::PageRendererHelper)

      compiled_html = case page.render_mode
                      when "builder"
                        view.render_builder_page(page)
                      when "html"
                        view.render_html_page(page)
                      else
                        return
                      end

      # Update page with compiled HTML
      page.update_columns(
        compiled_html: compiled_html,
        compiled_at: Time.current
      )
    end
  end
end
