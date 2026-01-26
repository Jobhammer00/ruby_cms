# frozen_string_literal: true

module RubyCms
  module Admin
    class NavigationMenusController < BaseController
      before_action { require_permission!(:manage_pages) }
      before_action :set_menu, only: %i[show edit update destroy]
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

      def index
        @menus = RubyCms::NavigationMenu.by_position
      end

      def show
        @items = @menu.navigation_items.includes(:children).root_items.by_position
      end

      def new
        @menu = RubyCms::NavigationMenu.new(published: true, position: 0)
      end

      def create
        @menu = RubyCms::NavigationMenu.new(menu_params)
        if @menu.save
          redirect_to ruby_cms_admin_navigation_menu_path(@menu), notice: "Navigation menu created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit; end

      def update
        if @menu.update(menu_params)
          redirect_to ruby_cms_admin_navigation_menu_path(@menu), notice: "Navigation menu updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @menu.destroy
        redirect_to ruby_cms_admin_navigation_menus_path, notice: "Navigation menu deleted."
      end

      private

      def set_menu
        @menu = RubyCms::NavigationMenu.find(params[:id])
      end

      def menu_params
        key = model_param_key(RubyCms::NavigationMenu, :navigation_menu)

        params.require(key).permit(:key, :name, :position, :published)
      end

      def handle_parameter_missing(_exception)
        @menu ||= RubyCms::NavigationMenu.new(published: true, position: 0)
        @menu.errors.add(:base, "Invalid form submission. Please try again.")

        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.any { head :bad_request }
        end
      end
    end
  end
end
