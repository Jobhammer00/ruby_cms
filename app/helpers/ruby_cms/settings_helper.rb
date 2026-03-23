# frozen_string_literal: true

module RubyCms
  module SettingsHelper
    TAB_CONFIG = {
      "general" => { icon: "🏠", fallback_label: "General" },
      "navigation" => { icon: "🧭", fallback_label: "Navigation" },
      "pagination" => { icon: "📄", fallback_label: "Pagination" },
      "analytics" => { icon: "📈", fallback_label: "Analytics" },
      "dashboard" => { icon: "🗂️", fallback_label: "Dashboard" },
      "content" => { icon: "🧱", fallback_label: "Content" }
    }.freeze

    def settings_tab_config(category)
      TAB_CONFIG[category.to_s] || { icon: "⚙️", fallback_label: category.to_s.humanize }
    end

    def settings_tab_label(category)
      cfg = settings_tab_config(category)
      t("ruby_cms.admin.settings.categories.#{category}.label", default: cfg[:fallback_label])
    end

    def settings_tab_description(category)
      t("ruby_cms.admin.settings.categories.#{category}.description", default: "")
    end

    def setting_label(entry)
      key = entry.key.to_s

      # Keep familiar labels for nav and pagination keys.
      key = key.delete_prefix("nav_show_")
      key = key.delete_suffix("_per_page")

      key.tr("_", " ").humanize
    end

    # SVG path fragment for a nav item (matches sidebar), or nil.
    def settings_nav_visibility_icon(entry)
      key_str = entry.key.to_s
      return nil unless key_str.start_with?("nav_show_")

      nav_key = key_str.delete_prefix("nav_show_")
      item = RubyCms.nav_registry.find { |e| e[:key].to_s == nav_key }
      item&.dig(:icon)
    end

    def render_setting_field(entry:, value:, tab:)
      case entry.type.to_sym
      when :integer
        render_integer_setting_field(entry:, value:, tab:)
      when :boolean
        render_boolean_setting_field(entry:, value:, tab:)
      when :json
        render_json_setting_field(entry:, value:, tab:)
      else
        render_string_setting_field(entry:, value:, tab:)
      end
    end

    private

    def input_base_classes
      "w-full h-9 rounded-lg border border-border bg-background px-3 text-sm text-foreground " \
        "shadow-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
    end

    def textarea_base_classes
      "w-full rounded-lg border border-border bg-background px-3 py-2 text-sm text-foreground " \
        "shadow-sm focus:outline-none focus:ring-2 focus:ring-primary/20"
    end

    def render_integer_setting_field(entry:, value:, tab:)
      min, max = integer_bounds_for(entry)

      number_field_tag(
        "preferences[#{entry.key}]",
        value,
        id: setting_input_id(entry),
        class: input_base_classes,
        min: min,
        max: max,
        data: autosave_data(entry.key, tab)
      )
    end

    def render_boolean_setting_field(entry:, value:, tab:)
      checked = ActiveModel::Type::Boolean.new.cast(value)
      hidden = hidden_field_tag("preferences[#{entry.key}]", "false")
      checkbox = check_box_tag(
        "preferences[#{entry.key}]",
        "true",
        checked,
        id: setting_input_id(entry),
        class: "peer sr-only",
        data: autosave_data(entry.key, tab)
      )
      label = content_tag(
        :label,
        "",
        for: setting_input_id(entry),
        class: "relative inline-flex h-7 w-12 cursor-pointer items-center rounded-full " \
               "border border-border bg-muted transition-colors peer-checked:bg-primary peer-checked:border-primary"
      ) do
        content_tag(
          :span,
          "",
          class: "inline-block h-5 w-5 transform rounded-full bg-background shadow-sm ring-1 ring-border transition " \
                 "translate-x-1 peer-checked:translate-x-6"
        )
      end

      content_tag(:div, class: "inline-flex items-center shrink-0") { hidden + checkbox + label }
    end

    def render_json_setting_field(entry:, value:, tab:)
      formatted = if value.kind_of?(Hash) || value.kind_of?(Array)
                    JSON.pretty_generate(value)
                  else
                    value.to_s
                  end

      text_area_tag(
        "preferences[#{entry.key}]",
        formatted,
        id: setting_input_id(entry),
        class: textarea_base_classes,
        rows: 4,
        data: autosave_data(entry.key, tab)
      )
    end

    def render_string_setting_field(entry:, value:, tab:)
      text_field_tag(
        "preferences[#{entry.key}]",
        value,
        id: setting_input_id(entry),
        class: input_base_classes,
        data: autosave_data(entry.key, tab)
      )
    end

    def autosave_data(key, tab)
      {
        controller: "ruby-cms--auto-save-preference",
        action: "change->ruby-cms--auto-save-preference#save",
        ruby_cms__auto_save_preference_preference_key_value: key.to_s,
        ruby_cms__auto_save_preference_settings_url_value: ruby_cms_admin_settings_path,
        ruby_cms__auto_save_preference_tab_value: tab.to_s
      }
    end

    def setting_input_id(entry)
      "pref_#{entry.key}"
    end

    def integer_bounds_for(entry)
      key = entry.key.to_s

      if key.end_with?("_per_page")
        min = RubyCms::Settings.get(:pagination_min_per_page, default: 5).to_i
        max = RubyCms::Settings.get(:pagination_max_per_page, default: 200).to_i
        return [min, [max, min].max]
      end

      [nil, nil]
    rescue StandardError
      [nil, nil]
    end
  end
end
