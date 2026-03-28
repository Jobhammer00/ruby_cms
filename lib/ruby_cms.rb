# frozen_string_literal: true

require_relative "ruby_cms/version"
require_relative "ruby_cms/css_compiler"
require_relative "ruby_cms/settings_registry"
require_relative "ruby_cms/settings"
require_relative "ruby_cms/icons"
require_relative "ruby_cms/dashboard_blocks"
require_relative "ruby_cms/engine"
require_relative "ruby_cms/app_integration"
require_relative "ruby_cms/content_blocks_sync"
require_relative "ruby_cms/content_blocks_grouping"

module RubyCms
  class Error < StandardError; end

  mattr_accessor :nav_registry
  self.nav_registry = []

  # Permission configuration (available at boot, before models load)
  DEFAULT_PERMISSION_KEYS = %w[
    manage_admin
    manage_permissions
    manage_content_blocks
    manage_visitor_errors
    manage_analytics
  ].freeze

  mattr_accessor :extra_permission_keys, default: []
  mattr_accessor :permission_templates, default: {}

  def self.register_permission_keys(*keys)
    self.extra_permission_keys = (extra_permission_keys + keys.flatten.map(&:to_s)).uniq
  end

  def self.register_permission_template(name, label:, keys:, description: nil)
    permission_templates[name.to_sym] = {
      label: label,
      keys: keys.map(&:to_s),
      description: description
    }
  end

  # Navigation section keys. Order in sidebar: main, then Settings (bottom).
  # User can add items to either via nav_register with section: NAV_SECTION_MAIN (order 10+)
  # or section: NAV_SECTION_BOTTOM (order 10+).
  NAV_SECTION_MAIN = "main"
  NAV_SECTION_BOTTOM = "Settings"

  def self.configure
    yield(Rails.application.config.ruby_cms)
  end

  def self.setting(key, default: nil)
    RubyCms::Settings.get(key, default:)
  end

  # Register a link for admin navigation.
  # Sections: main (top), Settings (bottom). Add to main with section: "main", order: 10+;
  # add to bottom with section: "Settings", order: 10+. Order can be changed via Settings → Navigation drag-and-drop.
  # Options:
  # - key: required Symbol/String
  # - label: required String
  # - path: String, Symbol (route helper name, auto-wrapped via main_app), or callable(view_context) -> path
  # - icon: Symbol (named icon from RubyCms::Icons) or raw SVG path fragment string
  # - section: "main" | "Settings" (or nil => main)
  # - order: optional Integer for sorting within section
  # - permission: optional permission key (e.g., :manage_analytics)
  # - default_visible: optional Boolean (default true)
  # - if: optional callable for custom visibility gate
  def self.nav_register(key:, label:, path:, icon: nil, section: nil, order: nil, permission: nil, default_visible: true, **options)
    normalized_key = key.to_sym
    normalized_section = section.presence || NAV_SECTION_MAIN
    resolved_path = path.kind_of?(Symbol) ? ->(v) { v.main_app.send(path) } : path
    resolved_icon = icon.nil? ? nil : RubyCms::Icons.resolve(icon)
    entry = {
      key: normalized_key,
      label: label.to_s,
      path: resolved_path,
      icon: resolved_icon,
      section: normalized_section,
      order: order,
      permission: permission&.to_s,
      default_visible: default_visible ? true : false,
      if: options[:if]
    }

    self.nav_registry = nav_registry.reject {|e| e[:key] == normalized_key }
    self.nav_registry += [entry]

    register_navigation_setting!(entry)

    entry
  end

  VALID_PAGE_SECTIONS = %i[main settings].freeze

  # Unified API to register an admin page: nav item + permission key in one call.
  # Accepts :main or :settings for section (resolved to NAV_SECTION_MAIN / NAV_SECTION_BOTTOM).
  # Automatically registers the permission key if provided.
  def self.register_page(
    key:, label:, path:, icon: nil, section: :main, order: nil,
    permission: nil, default_visible: true, **
  )
    raise ArgumentError, "register_page section must be :main or :settings, got #{section.inspect}" unless VALID_PAGE_SECTIONS.include?(section.to_s.to_sym)

    register_permission_keys(permission) if permission.present?
    resolved_section = section.to_s == "settings" ? NAV_SECTION_BOTTOM : NAV_SECTION_MAIN
    nav_register(
      key: key,
      label: label,
      path: path,
      icon: icon,
      section: resolved_section,
      order: order,
      permission: permission,
      default_visible: default_visible,
      **
    )
  end

  # Returns only entries that pass settings + permissions + conditional checks,
  # sorted by saved nav_order (Settings → Navigation drag-and-drop) when set, else by section + order.
  # Fail-closed: returns empty array on error (never exposes unfiltered items).
  def self.visible_nav_registry(view_context: nil, user: nil)
    list = nav_registry
           .select {|item| nav_entry_visible?(item, view_context:, user:) }
           .sort_by {|item| nav_sort_tuple(item) }
    localize_nav_labels(apply_nav_order(list))
  rescue StandardError => e
    Rails.logger.error("[RubyCMS] Error filtering navigation: #{e.message}") if defined?(Rails.logger)
    []
  end

  module Nav
    def self.register(key:, label:, path:, icon: nil, section: nil, order: nil, permission: nil, default_visible: true, **)
      RubyCms.nav_register(
        key:,
        label:,
        path:,
        icon:,
        section:,
        order:,
        permission:,
        default_visible:,
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

    def localize_nav_labels(list)
      list.map do |item|
        translated = I18n.t("ruby_cms.nav.items.#{item[:key]}", default: item[:label].to_s)
        item.merge(label: translated)
      end
    end

    def nav_section_priority(section)
      section.to_s == NAV_SECTION_MAIN ? 0 : 2
    end

    def apply_nav_order(list)
      # Read directly from DB so order is always from Settings, not Settings.get (which can return registry default).
      pref = RubyCms::Preference.find_by(key: "nav_order")
      return list unless pref&.value_type == "json" && pref.value.present?

      saved = JSON.parse(pref.value)
      return list unless saved.kind_of?(Array) && saved.any?

      order_map = saved.each_with_index.to_h {|k, i| [k.to_s, i] }
      list.sort_by {|item| order_map.fetch(item[:key].to_s, 9999) }
    rescue StandardError
      list
    end

    def nav_entry_visible?(item, view_context:, user:)
      return false unless setting_enabled_for_nav_item?(item)
      return false unless permission_allows_nav_item?(item, view_context:, user:)
      return false unless condition_allows_nav_item?(item, view_context:)

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
