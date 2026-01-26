# frozen_string_literal: true

# Page Builder Controller
#
# Handles all page builder functionality including:
# - Component palette management
# - Node creation, update, deletion, and reordering
# - Region management
# - Component schema retrieval
#
# Related files:
# - lib/ruby_cms/page_builder/ - Page builder module
# - app/helpers/ruby_cms/page_builder_helper.rb - View helpers
# - app/javascript/controllers/ruby_cms/page_builder_controller.js - Stimulus controller
# - app/views/ruby_cms/admin/page_builder/ - Views
module RubyCms
  module Admin
    class PageBuilderController < BaseController
      before_action :set_page,
                    only: %i[show update show_node create_node update_node destroy_node reorder_nodes create_region
                             component_schema]
      before_action { require_permission!(:manage_pages) }

      def index
        # Get all pages for selection
        @pages = RubyCms::Page.order(:key).all
        @page_id = params[:page_id].presence
        @page = @page_id ? RubyCms::Page.find_by(id: @page_id) : @pages.first

        return unless @page

        @components = RubyCms.all_components.group_by(&:category)
        @regions = @page.page_regions.includes(page_nodes: :children).by_position
      end

      def show
        @components = RubyCms.all_components.group_by(&:category)
        @regions = @page.page_regions.includes(page_nodes: :children).by_position
      end

      def component_schema
        component_key = params[:component_key]
        component = RubyCms.get_component(component_key)

        if component
          render json: {
            success: true,
            schema: component.schema,
            name: component.name,
            description: component.description
          }
        else
          render json: { success: false, error: "Component not found" }, status: :not_found
        end
      end

      def update
        # Update page metadata if needed
        @page.update(page_params) if params[:page].present?
        render json: { success: true, page: page_json }
      end

      def show_node
        set_page_from_params
        node = find_node_by_id(params[:id])
        render json: { success: true, node: node_json(node) }
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, error: "Node not found" }, status: :not_found
      end

      def create_node
        set_page_from_params
        region = @page.page_regions.find_by!(key: params[:region_key])
        node = region.page_nodes.build(node_params)

        # Merge default props from component schema
        component = RubyCms.get_component(node.component_key)
        if component&.schema.present?
          default_props = extract_default_props(component.schema)
          node.props = default_props.merge(node.props || {})
        end

        # Set position: if parent_id is present, count children of that parent; otherwise count root nodes
        if node.parent_id.present?
          parent = region.page_nodes.find(node.parent_id)
          node.position = parent.children.count
        else
          node.position = region.page_nodes.root_nodes.count
        end

        if node.save
          render json: { success: true, node: node_json(node) }
        else
          render json: { success: false, errors: node.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update_node
        set_page_from_params
        node = find_node_by_id(params[:id])

        # Handle region change if region_key is provided
        if params[:region_key].present?
          target_region = @page.page_regions.find_by(key: params[:region_key])
          if target_region && target_region.id != node.page_region_id
            node.page_region_id = target_region.id
          end
        end

        if node.update(node_params)
          render json: { success: true, node: node_json(node) }
        else
          render json: { success: false, errors: node.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy_node
        set_page_from_params
        node = find_node_by_id(params[:id])
        node.destroy
        render json: { success: true }
      end

      def reorder_nodes
        set_page_from_params
        region = @page.page_regions.find_by!(key: params[:region_key])

        # Support both flat list (backward compatible) and nested tree structure
        if params[:tree].present?
          # Nested tree: [{ id: 1, children: [{ id: 2 }, { id: 3 }] }, { id: 4 }]
          update_tree_structure(region, params[:tree])
        else
          # Flat list (backward compatible)
          node_ids = params[:node_ids] || []
          node_ids.each_with_index do |node_id, index|
            node = region.page_nodes.find(node_id)
            node.update(position: index, parent_id: nil)
          end
        end

        render json: { success: true }
      end

      def create_region
        set_page_from_params
        region = @page.page_regions.build(region_params)
        region.position = @page.page_regions.count

        if region.save
          render json: { success: true, region: region_json(region) }
        else
          render json: { success: false, errors: region.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_page
        page_id = params[:page_id] || params[:id]
        @page = RubyCms::Page.find(page_id) if page_id.present?
      end

      def set_page_from_params
        page_id = params[:page_id]
        @page = RubyCms::Page.find(page_id) if page_id.present?
        raise ActiveRecord::RecordNotFound, "Page ID required" unless @page
      end

      def page_params
        key = model_param_key(RubyCms::Page, :page)

        params.require(key).permit(:title, :published)
      end

      def node_params
        params.require(:node).permit(:component_key, :parent_id, props: {})
      end

      def region_params
        params.require(:region).permit(:key)
      end

      def find_node_by_id(node_id)
        RubyCms::PageNode.joins(:page_region).where(ruby_cms_page_regions: { page_id: @page.id }).find(node_id)
      end

      def page_json
        {
          id: @page.id,
          key: @page.key,
          title: @page.title,
          published: @page.published,
          regions: @page.page_regions.includes(:page_nodes).by_position.map { |r| region_json(r) }
        }
      end

      def region_json(region)
        {
          id: region.id,
          key: region.key,
          position: region.position,
          nodes: region.page_nodes.root_nodes.by_position.map { |n| node_json(n) }
        }
      end

      def node_json(node)
        {
          id: node.id,
          component_key: node.component_key,
          props: node.props,
          position: node.position,
          parent_id: node.parent_id,
          children: node.children.by_position.map { |c| node_json(c) }
        }
      end

      def update_tree_structure(region, tree, parent_id: nil, position_offset: 0)
        tree.each_with_index do |item, index|
          node_id = item[:id] || item["id"]
          children = item[:children] || item["children"] || []

          node = region.page_nodes.find(node_id)
          node.update!(
            parent_id: parent_id,
            position: position_offset + index
          )

          # Recursively update children
          update_tree_structure(region, children, parent_id: node_id, position_offset: 0) if children.any?
        end
      end

      # Extract default values from component schema properties
      def extract_default_props(schema)
        props = {}
        return props unless schema[:properties].is_a?(Hash)

        schema[:properties].each do |key, prop_schema|
          if prop_schema[:default].present?
            props[key.to_s] = prop_schema[:default]
          elsif schema[:required]&.include?(key.to_s) || schema[:required]&.include?(key.to_sym)
            # Provide sensible defaults for required fields without explicit defaults
            props[key.to_s] = case prop_schema[:type]
                              when "string" then placeholder_text_for(key.to_s)
                              when "number", "integer" then 0
                              when "boolean" then false
                              when "array" then []
                              when "object" then {}
                              else ""
                              end
          end
        end

        props
      end

      def placeholder_text_for(key)
        case key
        when "text" then "Enter text here..."
        when "title" then "Title"
        when "heading" then "Heading"
        when "content" then "Content goes here..."
        when "description" then "Description"
        when "label" then "Label"
        when "name" then "Name"
        when "url", "href", "link" then "#"
        when "src", "image" then ""
        else "..."
        end
      end
    end
  end
end
