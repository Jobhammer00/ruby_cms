# frozen_string_literal: true

module RubyCms
  class NavigationItem < ::ApplicationRecord
    self.table_name = "ruby_cms_navigation_items"

    belongs_to :navigation_menu, class_name: "RubyCms::NavigationMenu"
    belongs_to :parent, class_name: "RubyCms::NavigationItem", optional: true
    has_many :children, class_name: "RubyCms::NavigationItem", foreign_key: "parent_id", dependent: :destroy

    validates :label, presence: true
    validates :link_type, inclusion: { in: %w[url page route] }
    validate :link_type_specific_validation
    validate :no_circular_reference
    validate :route_name_whitelist, if: -> { link_type == "route" }

    scope :published, -> { where(published: true) }
    scope :by_position, -> { order(:position, :id) }
    scope :root_items, -> { where(parent_id: nil) }

    # Resolve the URL for this item based on link_type
    def resolve(view_context)
      url = case link_type
            when "url"
              self.url.presence || "#"
            when "page"
              page_key.present? ? view_context.ruby_cms_public_page_path(page_key) : "#"
            when "route"
              resolve_route(view_context)
            else
              "#"
            end

      {
        label: label,
        url: url,
        children: children.published.by_position.map { |child| child.resolve(view_context) },
        active: active?(view_context)
      }
    end

    private

    def link_type_specific_validation
      case link_type
      when "url"
        errors.add(:url, "is required for URL link type") if url.blank?
      when "page"
        errors.add(:page_key, "is required for page link type") if page_key.blank?
      when "route"
        errors.add(:route_name, "is required for route link type") if route_name.blank?
      end
    end

    def no_circular_reference
      return unless parent_id.present?

      # Prevent self-reference
      if parent_id == id
        errors.add(:parent_id, "cannot reference itself")
        return
      end

      return if parent.nil?

      # Check if any ancestor is this item (would create a cycle)
      current = parent
      visited = []
      while current.present?
        if current.id == id
          errors.add(:parent_id, "would create a circular reference")
          break
        end
        break if visited.include?(current.id)

        visited << current.id
        current = current.parent
      end
    end

    def route_name_whitelist
      return if route_name.blank?

      # Check if route_name is in registered app routes
      registered_routes = RubyCms.app_routes.values.map { |r| r[:route_name] }
      return if registered_routes.include?(route_name)

      # Allow Rails route helpers (must end with _path or _url)
      return if route_name.match?(/\A\w+_(path|url)\z/)

      errors.add(:route_name, "is not a registered route or valid route helper")
    end

    def resolve_route(view_context)
      return "#" unless route_name.present?

      begin
        # Try to resolve the route using the view context
        if view_context.respond_to?(route_name, true)
          if route_params.present? && route_params.is_a?(Hash)
            view_context.send(route_name, **route_params.symbolize_keys)
          else
            view_context.send(route_name)
          end
        elsif view_context.respond_to?(:main_app, true) && view_context.main_app.respond_to?(route_name, true)
          if route_params.present? && route_params.is_a?(Hash)
            view_context.main_app.send(route_name, **route_params.symbolize_keys)
          else
            view_context.main_app.send(route_name)
          end
        else
          "#"
        end
      rescue StandardError => e
        Rails.logger.warn "Failed to resolve route #{route_name}: #{e.message}" if defined?(Rails.logger)
        "#"
      end
    end

    def active?(view_context)
      current_path = begin
        view_context.request.path
      rescue StandardError
        nil
      end
      return false unless current_path

      case link_type
      when "url"
        current_path == url
      when "page"
        page_key.present? && current_path == view_context.ruby_cms_public_page_path(page_key)
      when "route"
        # Try to match against resolved route
        resolved = resolve_route(view_context)
        current_path == resolved
      else
        false
      end
    end
  end
end
