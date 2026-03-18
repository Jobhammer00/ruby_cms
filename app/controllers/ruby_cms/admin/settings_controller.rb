# frozen_string_literal: true

module RubyCms
  module Admin
    class SettingsController < BaseController
      before_action { require_permission!(:manage_admin) }

      def index
        RubyCms::Settings.ensure_defaults!

        @registry_entries = sorted_registry_entries
        @categories = @registry_entries.map {|e| e.category.to_s }.uniq
        @active_tab = resolve_active_tab(params[:tab], @categories)
        @entries_for_tab = @registry_entries.select {|entry| entry.category.to_s == @active_tab }

        @values = @entries_for_tab.to_h do |entry|
          [entry.key, RubyCms::Settings.get(entry.key, default: entry.default)]
        end
      end

      def update
        updated_keys = apply_updates(extract_updates)
        updated_keys = apply_nav_order_update(updated_keys)

        respond_with_update_success(updated_keys)
      rescue StandardError => e
        respond_with_update_failure(e)
      end

      def reset_defaults
        RubyCms::SettingsRegistry.seed_defaults!

        RubyCms::SettingsRegistry.each do |entry|
          RubyCms::Settings.set(entry.key, entry.default)
        end

        redirect_to ruby_cms_admin_settings_path(redirect_settings_params),
                    notice: t("ruby_cms.admin.settings.defaults_reset")
      end

      # Dedicated endpoint for saving nav order only. Reads raw JSON body; writes directly to preferences table.
      def update_nav_order
        order = nav_order_from_raw_body
        unless order.kind_of?(Array) && order.any?
          return render json: {
                          success: false,
                          error: "nav_order_main and nav_order_bottom required"
                        },
                        status: :unprocessable_content
        end

        rec = RubyCms::Preference.find_or_initialize_by(key: "nav_order")
        rec.category = "navigation" if rec.new_record?
        rec.value_type = "json"
        rec.value = order.map(&:to_s).to_json
        rec.save!
        render json: { success: true, updated_keys: ["nav_order"], updated_count: 1 }
      rescue StandardError => e
        render json: { success: false, error: e.message }, status: :unprocessable_content
      end

      private

      def nav_order_from_raw_body
        request.body.rewind if request.body.respond_to?(:rewind)
        body = request.body.read
        return [] if body.blank?

        data = JSON.parse(body)
        nav_order_from_raw_hash(data)
      rescue JSON::ParserError
        []
      end

      def redirect_settings_params
        { tab: params[:tab].presence || default_tab }.tap do |h|
          h[:nav_sub] = params[:nav_sub].presence if params[:tab].to_s == "navigation"
        end
      end

      # Persist nav order so it survives reload. Uses Preference directly so we hit the same row Settings.get reads.
      def persist_nav_order(order)
        return unless order.kind_of?(Array) && order.any?

        RubyCms::Preference.set("nav_order", order)
      end

      # For JSON PATCH, Rails may wrap body under :settings (or leave at root). Body stream can be
      # consumed by the parser so we try params first, then rewind and read raw body.
      def nav_order_arrays_from_request
        main = nav_order_param(:nav_order_main)
        bottom = nav_order_param(:nav_order_bottom)
        if main.nil? && bottom.nil? && request.content_mime_type&.symbol == :json
          data = parsed_json_body
          main, bottom = nav_order_arrays_from_json(data) if data
        end
        [
          main.kind_of?(Array) ? main.map(&:to_s) : Array(main).map(&:to_s),
          bottom.kind_of?(Array) ? bottom.map(&:to_s) : Array(bottom).map(&:to_s)
        ]
      end

      def nav_order_param(key)
        key_s = key.to_s
        # Root (symbol or string)
        params[key].presence || params[key_s].presence ||
          # Common Rails JSON wrapper
          params.dig(:settings, key).presence || params.dig(:settings, key_s).presence ||
          params.dig("settings", key).presence || params.dig("settings", key_s).presence
      end

      def parsed_json_body
        body = nil
        if request.body.respond_to?(:rewind)
          request.body.rewind
          body = request.body.read
        end
        body = request.raw_post if body.blank? && body != false
        return nil if body.blank?

        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      def sorted_registry_entries
        RubyCms::SettingsRegistry
          .entries
          .values
          .sort_by {|entry| [entry.category.to_s, entry.key.to_s] }
      end

      def resolve_active_tab(tab_param, categories)
        requested = tab_param.to_s
        return requested if categories.include?(requested)

        categories.first || "general"
      end

      def default_tab
        sorted_registry_entries.first&.category || "general"
      end

      def extract_updates
        if params[:preferences].present?
          params.require(:preferences).to_unsafe_h
        elsif params[:key].present?
          { params[:key].to_s => params[:value] }
        else
          {}
        end
      end

      def apply_updates(updates)
        updates.filter_map do |key, value|
          entry = RubyCms::SettingsRegistry.fetch(key)
          next unless entry

          RubyCms::Settings.set(entry.key, value)
          entry.key
        end
      end

      def apply_nav_order_update(updated_keys)
        nav_main, nav_bottom = nav_order_arrays_from_request
        return updated_keys if nav_main.blank? && nav_bottom.blank?

        order = (nav_main + nav_bottom).map(&:to_s)
        persist_nav_order(order)
        updated_keys + ["nav_order"]
      end

      def respond_with_update_success(updated_keys)
        respond_to do |format|
          format.html do
            redirect_to ruby_cms_admin_settings_path(redirect_settings_params),
                        notice: t("ruby_cms.admin.settings.updated_many",
                                  default: "#{updated_keys.size} setting(s) updated.")
          end

          format.json do
            render json: {
              success: true,
              updated_keys: updated_keys,
              updated_count: updated_keys.size
            }
          end
        end
      end

      def respond_with_update_failure(error)
        respond_to do |format|
          format.html do
            redirect_to ruby_cms_admin_settings_path(redirect_settings_params),
                        alert: error.message
          end

          format.json do
            render json: { success: false, error: error.message }, status: :unprocessable_content
          end
        end
      end

      def nav_order_from_raw_hash(data)
        main = data["nav_order_main"]
        bottom = data["nav_order_bottom"]
        main = Array(main).map(&:to_s) if main
        bottom = Array(bottom).map(&:to_s) if bottom
        (main || []) + (bottom || [])
      end

      def nav_order_arrays_from_json(data)
        main = data.dig("settings", "nav_order_main") ||
               data["nav_order_main"].presence ||
               data[:nav_order_main].presence
        bottom = data.dig("settings", "nav_order_bottom") ||
                 data["nav_order_bottom"].presence ||
                 data[:nav_order_bottom].presence
        [main, bottom]
      end
    end
  end
end
