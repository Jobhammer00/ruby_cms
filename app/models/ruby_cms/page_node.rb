# frozen_string_literal: true

module RubyCms
  class PageNode < ::ApplicationRecord
    self.table_name = "ruby_cms_page_nodes"

    belongs_to :page_region, class_name: "RubyCms::PageRegion", touch: true
    belongs_to :parent, class_name: "RubyCms::PageNode", optional: true
    has_many :children, class_name: "RubyCms::PageNode", foreign_key: "parent_id",
                        dependent: :destroy

    validates :component_key, presence: true
    validates :component_key, inclusion: {
      in: lambda {|_node|
            RubyCms.component_registry.all.map(&:key)
          }, message: "is not a registered component"
    }

    scope :by_position, -> { order(:position, :id) }
    scope :root_nodes, -> { where(parent_id: nil) }
    scope :at_depth, ->(d) { where(depth: d) }
    scope :max_depth, ->(max) { where("depth <= ?", max) }

    # Validate props against component schema
    validate :validate_props_against_schema
    validate :max_depth_allowed
    validate :dependencies_available

    before_validation :calculate_depth, on: :create
    before_validation :recalculate_depth, on: :update, if: :parent_id_changed?
    after_commit :trigger_page_compile, if: -> { page_region&.page&.builder_mode? }

    MAX_DEPTH = 10

    # Get the depth of this node (0 for root nodes)
    def depth_level
      depth || calculate_depth_value
    end

    # Check if this node can have children (not at max depth)
    def can_have_children?
      depth_level < MAX_DEPTH
    end

    # Get all ancestors (parent chain)
    def ancestors
      return [] unless parent

      [parent] + parent.ancestors
    end

    # Get all descendants (all children recursively)
    def descendants
      children.flat_map {|child| [child] + child.descendants }
    end

    private

    def trigger_page_compile
      page_region&.page&.enqueue_compile if page_region&.page&.published?
    end

    def calculate_depth
      self.depth = calculate_depth_value
    end

    def calculate_depth_value
      return 0 unless parent_id.present?

      parent_node = parent || RubyCms::PageNode.find_by(id: parent_id)
      return 0 unless parent_node

      parent_node.depth_level + 1
    end

    def recalculate_depth
      new_depth = calculate_depth_value
      return unless depth != new_depth

      self.depth = new_depth
      # Recursively update children depths
      update_children_depths
    end

    def update_children_depths
      children.find_each do |child|
        child.depth = depth + 1
        child.save(validate: false)
        child.send(:update_children_depths)
      end
    end

    def max_depth_allowed
      return unless parent_id.present?

      parent_node = parent || RubyCms::PageNode.find_by(id: parent_id)
      return unless parent_node

      return unless parent_node.depth_level >= MAX_DEPTH - 1

      errors.add(:parent_id, "would exceed maximum nesting depth of #{MAX_DEPTH}")
    end

    def dependencies_available
      component = RubyCms.get_component(component_key)
      return unless component&.dependencies.present?

      # Check if all dependencies are available in the same region
      available_component_keys = page_region&.page_nodes&.pluck(:component_key) || []
      available_component_keys << component_key # Include self

      missing_deps = component.dependencies.reject do |dep|
        available_component_keys.include?(dep.to_s)
      end
      return unless missing_deps.any?

      errors.add(:component_key,
                 "requires dependencies that are not available: #{missing_deps.join(', ')}")
    end

    def validate_props_against_schema
      component = RubyCms.get_component(component_key)
      return unless component&.schema.present?

      schema = component.schema

      # Check required fields
      if schema[:required].kind_of?(Array)
        schema[:required].each do |required_key|
          unless props.key?(required_key.to_s) || props.key?(required_key.to_sym)
            errors.add(:props, "missing required field: #{required_key}")
          end
        end
      end

      # Type validation (simplified)
      return unless schema[:properties].kind_of?(Hash)

      schema[:properties].each do |prop_key, prop_schema|
        next unless props.key?(prop_key.to_s) || props.key?(prop_key.to_sym)

        value = props[prop_key.to_s] || props[prop_key.to_sym]

        # Skip validation for nil or empty string values (optional fields)
        next if value.nil? || (value.kind_of?(String) && value.empty?)

        expected_type = prop_schema[:type]

        next unless expected_type

        type_valid = case expected_type
                     when "string"
                       value.kind_of?(String)
                     when "number", "integer"
                       value.kind_of?(Numeric)
                     when "boolean"
                       value.kind_of?(TrueClass) || value.kind_of?(FalseClass)
                     when "array"
                       value.kind_of?(Array)
                     when "object"
                       value.kind_of?(Hash)
                     else
                       true
                     end

        unless type_valid
          errors.add(:props,
                     "#{prop_key} has wrong type. Expected #{expected_type}, got #{value.class}")
        end
      end
    end
  end
end
