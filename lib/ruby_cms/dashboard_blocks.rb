# frozen_string_literal: true

# Loaded from lib/ruby_cms.rb and from lib/ruby_cms/engine.rb so dashboard API exists even when
# the host only requires "ruby_cms/engine" (without loading lib/ruby_cms.rb first).
module RubyCms
  mattr_accessor :dashboard_registry
  self.dashboard_registry = []

  # Register a dashboard block (stats row or main row). Host apps can add blocks or replace defaults by key.
  def self.dashboard_register(
    key:, label:, section:, order:, partial: nil, render: nil, permission: nil,
    enabled: true, default_visible: true, span: :single, data: nil
  )
    normalized_key = key.to_sym
    normalized_section = section.to_sym
    raise ArgumentError, "section must be :stats or :main" unless %i[stats main].include?(normalized_section)

    raise ArgumentError, "partial or render is required" if partial.blank? && !render.respond_to?(:call)

    entry = {
      key: normalized_key,
      label: label.to_s,
      section: normalized_section,
      order: order.to_i,
      partial: partial,
      render: render,
      permission: permission&.to_sym,
      enabled: enabled ? true : false,
      default_visible: default_visible ? true : false,
      span: span.to_sym == :double ? :double : :single,
      data: data
    }

    self.dashboard_registry = dashboard_registry.reject {|e| e[:key] == normalized_key }
    self.dashboard_registry += [entry]

    register_dashboard_setting!(entry)
    entry
  end

  def self.visible_dashboard_blocks(user: nil)
    dashboard_registry
      .select {|e| e[:enabled] }
      .select {|e| dashboard_block_visible?(e, user:) }
      .sort_by {|e| [e[:section] == :stats ? 0 : 1, e[:order], e[:label]] }
  rescue StandardError => e
    Rails.logger.error("[RubyCMS] Error filtering dashboard blocks: #{e.message}") if defined?(Rails.logger)
    []
  end

  class << self
    private

    def register_dashboard_setting!(entry)
      RubyCms::SettingsRegistry.register(
        key: :"dashboard_show_#{entry[:key]}",
        type: :boolean,
        default: entry.fetch(:default_visible, true),
        category: :dashboard,
        description: "Show #{entry[:label]} on the admin dashboard"
      )
    rescue StandardError => e
      Rails.logger.warn("[RubyCMS] Failed to register dashboard setting for #{entry[:key]}: #{e.message}") if defined?(Rails.logger)
    end

    def dashboard_block_visible?(entry, user:)
      return false unless setting_enabled_for_dashboard_block?(entry)
      return false unless permission_allows_dashboard_block?(entry, user:)

      true
    end

    def setting_enabled_for_dashboard_block?(entry)
      pref_key = :"dashboard_show_#{entry[:key]}"
      RubyCms::Settings.get(pref_key, default: entry.fetch(:default_visible, true))
    rescue StandardError
      entry.fetch(:default_visible, true)
    end

    def permission_allows_dashboard_block?(entry, user:)
      permission_key = entry[:permission]
      return true if permission_key.blank?
      return false if user.nil?
      return true unless user.respond_to?(:can?)

      user.can?(permission_key)
    rescue StandardError
      false
    end
  end
end
