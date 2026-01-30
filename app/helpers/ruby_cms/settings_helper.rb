# frozen_string_literal: true

module RubyCms
  module SettingsHelper
    # Helper to render appropriate input for each preference type
    def render_preference_field(pref)
      case pref.value_type
      when "integer"
        number_field_tag "preferences[#{pref.key}]", pref.typed_value,
                         class: "ruby_cms-input",
                         min: (pref.key.end_with?("_per_page") ? 5 : nil),
                         max: (pref.key.end_with?("_per_page") ? 200 : nil),
                         data: {
                           controller: "ruby-cms--auto-save-preference",
                           action: "change->ruby-cms--auto-save-preference#save",
                           ruby_cms__auto_save_preference_preference_key_value: pref.key
                         }
      when "boolean"
        content_tag(:div, class: "ruby_cms-toggle") do
          check_box_tag("preferences[#{pref.key}]", "true", pref.typed_value,
                        class: "ruby_cms-toggle-checkbox",
                        data: {
                          controller: "ruby-cms--auto-save-preference",
                          action: "change->ruby-cms--auto-save-preference#save",
                          ruby_cms__auto_save_preference_preference_key_value: pref.key
                        }) +
            content_tag(:label, "", for: "preferences_#{pref.key}", class: "ruby_cms-toggle-label")
        end
      else
        text_field_tag "preferences[#{pref.key}]", pref.typed_value,
                       class: "ruby_cms-input",
                       data: {
                         controller: "ruby-cms--auto-save-preference",
                         action: "change->ruby-cms--auto-save-preference#save",
                         ruby_cms__auto_save_preference_preference_key_value: pref.key
                       }
      end
    end
  end
end
