# frozen_string_literal: true

module RubyCms
  # App Integration: Connect CMS to host app features
  module AppIntegration
    # Link App: Connect CMS pages to app routes/controllers
    module LinkApp
      # Register an app route that can be linked from CMS
      # @param key [String] Unique identifier for the route
      # @param route_name [String] Route helper name (e.g. "products_path", "user_dashboard_path")
      # @param label [String] Display label
      # @param description [String] Optional description
      # @param params [Hash] Default route parameters
      def self.register_route(key:, route_name:, label:, description: nil, params: {})
        @registered_routes ||= {}
        @registered_routes[key] = {
          route_name: route_name,
          label: label,
          description: description,
          params: params
        }
      end

      # Get all registered routes
      def self.registered_routes
        @registered_routes || {}
      end

      # Get a route by key
      def self.get_route(key)
        registered_routes[key.to_s]
      end
    end

    # App Settings: Load app-specific settings/config into CMS context
    module AppSettings
      # Register a setting that can be loaded into CMS context
      # @param key [String] Setting key
      # @param loader [Proc] Callable that returns the setting value: ->(view_context) { ... }
      def self.register_setting(key:, loader:)
        @registered_settings ||= {}
        @registered_settings[key.to_s] = loader
      end

      # Get all settings for a view context
      def self.load_settings(view_context)
        (@registered_settings || {}).transform_values do |loader|
          loader.call(view_context)
        end
      end

      # Get a specific setting
      def self.get_setting(key, view_context)
        loader = (@registered_settings || {})[key.to_s]
        loader&.call(view_context)
      end
    end
  end

  # Convenience methods
  class << self
    # Register an app route
    def register_app_route(**kwargs)
      AppIntegration::LinkApp.register_route(**kwargs)
    end

    # Get registered routes
    def app_routes
      AppIntegration::LinkApp.registered_routes
    end

    # Register an app setting
    def register_app_setting(**kwargs)
      AppIntegration::AppSettings.register_setting(**kwargs)
    end

    # Load app settings for view context
    def load_app_settings(view_context)
      AppIntegration::AppSettings.load_settings(view_context)
    end
  end
end
