# frozen_string_literal: true

module RubyCms
  module NavigationHelper
    # Render a navigation menu by key
    # @param menu_key [String] The navigation menu key
    # @param options [Hash] Rendering options (class, etc.)
    def render_navigation_menu(menu_key, **options)
      menu = RubyCms::NavigationMenu.published.find_by(key: menu_key)
      return "" unless menu

      items = menu.resolved_items(self)
      return "" if items.empty?

      render_navigation_items(items, **options)
    end

    # Render navigation items (recursive for nested items)
    def render_navigation_items(items, class: "space-y-1",
                                item_class: "block px-3 py-2 rounded-md text-sm font-medium", active_class: "bg-blue-50 text-blue-700", inactive_class: "text-gray-700 hover:bg-gray-100 hover:text-gray-900")
      tag.ul(class: binding.local_variable_get(:class)) do
        items.map do |item|
          tag.li do
            link = link_to item[:label], item[:url],
                           class: "#{binding.local_variable_get(:item_class)} #{item[:active] ? binding.local_variable_get(:active_class) : binding.local_variable_get(:inactive_class)}"

            if item[:children].any?
              link + render_navigation_items(item[:children], class: "ml-4 mt-1 space-y-1", item_class: item_class,
                                                              active_class: active_class, inactive_class: inactive_class)
            else
              link
            end
          end
        end.join.html_safe
      end
    end

    # Get app settings loaded into view context
    def cms_app_settings
      @cms_app_settings ||= RubyCms.load_app_settings(self)
    end

    # Get a specific app setting
    def cms_app_setting(key)
      cms_app_settings[key.to_s]
    end
  end
end
