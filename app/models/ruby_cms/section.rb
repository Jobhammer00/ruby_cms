# frozen_string_literal: true

module RubyCms
  class Section < ::ApplicationRecord
    self.table_name = "ruby_cms_sections"

    validates :key, presence: true, uniqueness: true
    validates :key, format: { with: /\A[\w-]+\z/, message: "only letters, numbers, hyphens, and underscores" }
    validates :name, presence: true

    scope :published, -> { where(published: true) }
    scope :by_position, -> { order(:position, :key) }

    # Apply this section to a page (creates regions and nodes)
    # @param page [RubyCms::Page] The page to apply the section to
    # @return [Array<RubyCms::PageRegion>] Created regions
    def apply_to_page(page)
      return [] unless region_data.is_a?(Hash)

      created_regions = []

      region_data.each do |region_key, region_info|
        next unless region_info.is_a?(Hash)

        region = page.page_regions.find_or_create_by(key: region_key) do |r|
          r.position = page.page_regions.count
        end

        # Create nodes from region data
        if region_info[:nodes].is_a?(Array)
          region_info[:nodes].each_with_index do |node_data, index|
            next unless node_data.is_a?(Hash)

            node = region.page_nodes.build(
              component_key: node_data[:component_key],
              props: node_data[:props] || {},
              position: index,
              depth: node_data[:depth] || 0
            )

            # Handle nested children
            if node_data[:children].is_a?(Array)
              create_nested_nodes(node, node_data[:children], 1)
            end

            node.save
          end
        end

        created_regions << region
      end

      created_regions
    end

    # Create section from page regions
    # @param page [RubyCms::Page] The page to extract sections from
    # @param region_keys [Array<String>] Region keys to include
    # @return [Hash] Region data structure
    def self.extract_from_page(page, region_keys = nil)
      regions = page.page_regions.includes(page_nodes: :children).by_position
      regions = regions.where(key: region_keys) if region_keys.present?

      data = {}
      regions.each do |region|
        data[region.key] = {
          nodes: region.page_nodes.root_nodes.by_position.map do |node|
            serialize_node(node)
          end
        }
      end

      data
    end

    private

    def create_nested_nodes(parent_node, children_data, current_depth)
      children_data.each_with_index do |child_data, index|
        next unless child_data.is_a?(Hash)

        child = parent_node.children.build(
          component_key: child_data[:component_key],
          props: child_data[:props] || {},
          position: index,
          depth: current_depth
        )

        if child_data[:children].is_a?(Array)
          create_nested_nodes(child, child_data[:children], current_depth + 1)
        end

        child.save
      end
    end

    def self.serialize_node(node)
      data = {
        component_key: node.component_key,
        props: node.props || {},
        depth: node.depth
      }

      if node.children.any?
        data[:children] = node.children.by_position.map { |child| serialize_node(child) }
      end

      data
    end
  end
end
