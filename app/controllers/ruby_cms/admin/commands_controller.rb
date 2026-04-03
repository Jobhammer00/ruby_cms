# frozen_string_literal: true

module RubyCms
  module Admin
    class CommandsController < BaseController
      cms_page :commands

      # HTML: POST/redirect/GET — URL blijft /settings/commands (geen /run in de adresbalk).
      RUN_CACHE_PREFIX = "ruby_cms/commands/run/v1/"
      FLASH_RUN = :ruby_cms_commands_run

      def index
        @commands = visible_commands
        consume_run_payload_from_flash
      end

      def run
        key = params.permit(:key)[:key].presence || params.dig(:command, :key)
        cmd = RubyCms.find_command(key)
        unless cmd
          return respond_to do |format|
            format.html do
              redirect_to ruby_cms_admin_settings_commands_path,
                          alert: t("ruby_cms.admin.commands.unknown", default: "Unknown command.")
            end
            format.json { render json: { error: "Unknown command" }, status: :not_found }
          end
        end

        require_permission!(cmd[:permission])

        output = utf8_text(RubyCms::CommandRunner.run_rake(cmd[:rake_task]))
        log_tail = utf8_text(RubyCms::CommandRunner.tail_log)

        respond_to do |format|
          format.html do
            token = persist_run_payload_for_redirect(output: output, log_tail: log_tail)
            redirect_to ruby_cms_admin_settings_commands_path,
                        status: :see_other,
                        flash: { FLASH_RUN => token }
          end
          format.json do
            render json: {
              command_output: output,
              app_log_tail: log_tail
            }
          end
        end
      rescue StandardError => e
        Rails.logger.error("[RubyCMS] Commands#run: #{e.class}: #{e.message}")
        respond_to do |format|
          format.html do
            token = persist_run_payload_for_redirect(error: utf8_text(e.message))
            redirect_to ruby_cms_admin_settings_commands_path,
                        status: :see_other,
                        flash: { FLASH_RUN => token }
          end
          format.json { render json: { error: e.message }, status: :unprocessable_entity }
        end
      end

      private

      def persist_run_payload_for_redirect(output: nil, log_tail: nil, error: nil)
        payload = { output: output, log_tail: log_tail, error: error }.compact
        token = SecureRandom.urlsafe_base64(32)
        if rails_cache_null_store?
          session[session_run_key(token)] = payload
        else
          Rails.cache.write("#{RUN_CACHE_PREFIX}#{token}", payload, expires_in: 15.minutes)
        end
        token
      end

      def consume_run_payload_from_flash
        token = flash[FLASH_RUN]
        return if token.blank?

        payload = load_run_payload(token)
        assign_run_ivars_from_payload(payload) if payload.is_a?(Hash)
      end

      def load_run_payload(token)
        if rails_cache_null_store?
          session.delete(session_run_key(token))
        else
          key = "#{RUN_CACHE_PREFIX}#{token}"
          data = Rails.cache.read(key)
          Rails.cache.delete(key) if data
          data
        end
      end

      def assign_run_ivars_from_payload(payload)
        p = payload.with_indifferent_access
        @run_error = utf8_text(p[:error]) if p[:error].present?
        @run_command_output = utf8_text(p[:output]) if p.key?(:output)
        @run_app_log_tail = utf8_text(p[:log_tail]) if p.key?(:log_tail)
      end

      def rails_cache_null_store?
        Rails.cache.is_a?(ActiveSupport::Cache::NullStore)
      end

      def session_run_key(token)
        "#{RUN_CACHE_PREFIX}#{token}"
      end

      # Rake / log IO is often ASCII-8BIT; ERB buffers are UTF-8 — normalize before render/JSON.
      def utf8_text(value)
        return +"" if value.nil?

        value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "?")
      end

      def visible_commands
        RubyCms.registered_commands.select {|c| current_user_cms&.can?(c[:permission]) }
                              .sort_by {|c| [ c[:label].to_s.downcase, c[:key] ] }
      end
    end
  end
end
