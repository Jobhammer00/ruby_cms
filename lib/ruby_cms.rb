# frozen_string_literal: true

require_relative "ruby_cms/version"
require_relative "ruby_cms/css_compiler"
require_relative "ruby_cms/settings_registry"
require_relative "ruby_cms/settings"
require_relative "ruby_cms/engine"
require_relative "ruby_cms/app_integration"
require_relative "ruby_cms/content_blocks_sync"
require_relative "ruby_cms/content_blocks_grouping"

module RubyCms
  class Error < StandardError; end

  mattr_accessor :nav_registry
  self.nav_registry = []

  # Navigation section keys. Order in sidebar: main, then Settings (bottom).
  # User can add items to either via nav_register with section: NAV_SECTION_MAIN (order 10+)
  # or section: NAV_SECTION_BOTTOM (order 10+).
  NAV_SECTION_MAIN = "main"
  NAV_SECTION_BOTTOM = "Settings"

  ANALYTICS_ICON_PATH = '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                        'd="M3 3v18h18"></path>' \
                        '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" ' \
                        'd="M7 13l3-3 3 2 4-5"></path>'.freeze

  def self.configure
    yield(Rails.application.config.ruby_cms)
  end

  def self.setting(key, default: nil)
    RubyCms::Settings.get(key, default: default)
  end

  # Register a link for admin navigation.
  # Sections: main (top), Settings (bottom). Add to main with section: "main", order: 10+;
  # add to bottom with section: "Settings", order: 10+. Order can be changed via Settings → Navigation drag-and-drop.
  # Options:
  # - key: required Symbol/String
  # - label: required String
  # - path: required String or callable(view_context) -> path
  # - icon: optional SVG path fragment
  # - section: "main" | "Settings" (or nil => main)
  # - order: optional Integer for sorting within section
  # - permission: optional permission key (e.g., :manage_analytics)
  # - default_visible: optional Boolean (default true)
  # - if: optional callable for custom visibility gate
  def self.nav_register(key:, label:, path:, icon: nil, section: nil, order: nil, permission: nil, default_visible: true, **options) # rubocop:disable Metrics/ParameterLists
    normalized_key = key.to_sym
    normalized_section = section.presence || NAV_SECTION_MAIN
    entry = {
      key: normalized_key,
      label: label.to_s,
      path: path,
      icon: icon,
      section: normalized_section,
      order: order,
      permission: permission&.to_s,
      default_visible: !!default_visible,
      if: options[:if]
    }

    self.nav_registry = nav_registry.reject { |e| e[:key] == normalized_key }
    self.nav_registry += [entry]

    register_navigation_setting!(entry)

    entry
  end

  # Returns only entries that pass settings + permissions + conditional checks,
  # sorted by saved nav_order (Settings → Navigation drag-and-drop) when set, else by section + order.
  def self.visible_nav_registry(view_context: nil, user: nil)
    list = nav_registry
           .select { |item| nav_entry_visible?(item, view_context: view_context, user: user) }
           .sort_by { |item| nav_sort_tuple(item) }
    list = apply_nav_order(list)
    list
  rescue StandardError => e
    Rails.logger.error("[RubyCMS] Error filtering navigation: #{e.message}") if defined?(Rails.logger)
    nav_registry
  end

  module Nav
    def self.register(key:, label:, path:, icon: nil, section: nil, order: nil, permission: nil, default_visible: true, **) # rubocop:disable Metrics/ParameterLists
      RubyCms.nav_register(
        key: key,
        label: label,
        path: path,
        icon: icon,
        section: section,
        order: order,
        permission: permission,
        default_visible: default_visible,
        **
      )
    end
  end

  class << self
    private

    def nav_sort_tuple(item)
      section = item[:section].to_s.presence || NAV_SECTION_MAIN
      priority = nav_section_priority(section)
      [priority, item[:order] || 1000, item[:label].to_s]
    end

    def nav_section_priority(section)
      section.to_s == NAV_SECTION_MAIN ? 0 : 2
    end

    def apply_nav_order(list)
      # Read directly from DB so order is always from Settings, not Settings.get (which can return registry default).
      pref = RubyCms::Preference.find_by(key: "nav_order")
      return list unless pref&.value_type == "json" && pref.value.present?

      saved = JSON.parse(pref.value)
      return list unless saved.is_a?(Array) && saved.any?

      order_map = saved.each_with_index.to_h { |k, i| [k.to_s, i] }
      list.sort_by { |item| order_map.fetch(item[:key].to_s, 9999) }
    rescue JSON::ParserError, StandardError
      list
    end

    def nav_entry_visible?(item, view_context:, user:)
      return false unless setting_enabled_for_nav_item?(item)
      return false unless permission_allows_nav_item?(item, view_context: view_context, user: user)
      return false unless condition_allows_nav_item?(item, view_context: view_context)

      true
    end

    def setting_enabled_for_nav_item?(item)
      pref_key = :"nav_show_#{item[:key]}"
      RubyCms::Settings.get(pref_key, default: item.fetch(:default_visible, true))
    rescue StandardError
      item.fetch(:default_visible, true)
    end

    def permission_allows_nav_item?(item, view_context:, user:)
      permission_key = item[:permission]
      return true if permission_key.blank?

      current_user = user || user_from_view_context(view_context)
      return false if current_user.nil?
      return true unless current_user.respond_to?(:can?)

      current_user.can?(permission_key.to_sym)
    rescue StandardError
      false
    end

    def condition_allows_nav_item?(item, view_context:)
      condition = item[:if]
      return true unless condition.respond_to?(:call)

      case condition.arity
      when 1
        condition.call(view_context)
      else
        condition.call
      end
    rescue StandardError
      false
    end

    def user_from_view_context(view_context)
      return nil unless view_context

      return view_context.current_user_cms if view_context.respond_to?(:current_user_cms)
      return view_context.current_user if view_context.respond_to?(:current_user)

      nil
    end

    def register_navigation_setting!(entry)
      key = :"nav_show_#{entry[:key]}"

      RubyCms::SettingsRegistry.register(
        key: key,
        type: :boolean,
        default: entry.fetch(:default_visible, true),
        category: :navigation,
        description: "Show #{entry[:label]} in navigation"
      )
    rescue StandardError => e
      Rails.logger.warn("[RubyCMS] Failed to register nav setting for #{entry[:key]}: #{e.message}") if defined?(Rails.logger)
    end
  end
end

RubyCms::SettingsRegistry.seed_defaults!
