# frozen_string_literal: true

module RubyCms
  module Admin
    class PagesController < BaseController
      before_action { require_permission!(:manage_pages) }
      before_action :set_page, only: %i[show edit update destroy]
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

      def index
        @pages = RubyCms::Page.by_position
      end

      def show; end

      def new
        @page = RubyCms::Page.new(published: true, position: 0)
        @templates = RubyCms.all_templates
        @template_key = params[:template]
      end

      def create
        @page = RubyCms::Page.new(page_params)

        # Apply template if specified
        if params[:template_key].present? && RubyCms.template_registered?(params[:template_key])
          begin
            RubyCms.apply_template_to_page(@page, params[:template_key])
          rescue StandardError => e
            @page.errors.add(:base, "Failed to apply template: #{e.message}")
            @templates = RubyCms.all_templates
            render :new, status: :unprocessable_entity
            return
          end
        end

        if @page.save
          redirect_to ruby_cms_admin_page_path(@page), notice: "Page created."
        else
          @templates = RubyCms.all_templates
          render :new, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing
        @page = RubyCms::Page.new(published: true, position: 0)
        @page.errors.add(:base, "Invalid form submission. Please try again.")
        render :new, status: :unprocessable_entity
      end

      def edit; end

      def update
        if @page.update(page_params)
          redirect_to ruby_cms_admin_page_path(@page), notice: "Page updated."
        else
          render :edit, status: :unprocessable_entity
        end
      rescue ActionController::ParameterMissing
        @page.errors.add(:base, "Invalid form submission. Please try again.")
        render :edit, status: :unprocessable_entity
      end

      def destroy
        @page.destroy
        redirect_to ruby_cms_admin_pages_path, notice: "Page deleted."
      end

      private

      def set_page
        @page = RubyCms::Page.find(params[:id])
      end

      def page_params
        key = model_param_key(RubyCms::Page, :page)

        params.require(key).permit(:key, :template_path, :title, :published, :position, :render_mode, :body_html,
                                   :layout)
      end

      def handle_parameter_missing(_exception)
        @page ||= RubyCms::Page.new(published: true, position: 0)
        @page.errors.add(:base, "Invalid form submission. Please try again.")

        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.any { head :bad_request }
        end
      end
    end
  end
end
