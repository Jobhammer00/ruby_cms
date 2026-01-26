# frozen_string_literal: true

module RubyCms
  module Admin
    class NavigationItemsController < BaseController
      before_action { require_permission!(:manage_pages) }
      before_action :set_menu
      before_action :set_item, only: %i[show edit update destroy]
      before_action :load_form_data, only: %i[new create edit update]
      rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

      def index
        @items = @menu.navigation_items.includes(:children).root_items.by_position
      end

      def show; end

      def new
        @item = @menu.navigation_items.build(published: true, position: 0)
      end

      def create
        @item = @menu.navigation_items.build(item_params)
        if @item.save
          redirect_to ruby_cms_admin_navigation_menu_path(@menu), notice: "Navigation item created."
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @item.update(item_params)
          redirect_to ruby_cms_admin_navigation_menu_path(@menu), notice: "Navigation item updated."
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @item.destroy
        redirect_to ruby_cms_admin_navigation_menu_path(@menu), notice: "Navigation item deleted."
      end

      def reorder
        item_ids = params[:item_ids] || []
        ActiveRecord::Base.transaction do
          item_ids.each_with_index do |item_id, index|
            @menu.navigation_items.find(item_id).update!(position: index)
          end
        end
        render json: { success: true }
      end

      private

      def set_menu
        @menu = RubyCms::NavigationMenu.find(params[:navigation_menu_id])
      end

      def set_item
        @item = @menu.navigation_items.find(params[:id])
      end

      def item_params
        key = model_param_key(RubyCms::NavigationItem, :navigation_item)

        params.require(key).permit(:label, :url, :page_key, :route_name, :link_type, :position, :published, :parent_id,
                                   route_params: {})
      end

      def handle_parameter_missing(_exception)
        @item ||= @menu.navigation_items.build(published: true, position: 0)
        @item.errors.add(:base, "Invalid form submission. Please try again.")
        load_form_data

        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.any { head :bad_request }
        end
      end

      def load_form_data
        @app_routes = RubyCms.app_routes
        @pages = RubyCms::Page.published.by_position
      end
    end
  end
end
