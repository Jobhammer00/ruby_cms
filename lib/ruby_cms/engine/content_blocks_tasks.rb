# frozen_string_literal: true

module RubyCms
  module EngineContentBlocksTasks
    def parse_locales_dir(locales_dir_arg)
      return nil unless locales_dir_arg.presence

      Pathname.new(locales_dir_arg)
    end

    def parse_import_options
      {
        create_missing: ENV["create_missing"] != "false",
        update_existing: ENV["update_existing"] != "false",
        published: ENV["published"] == "true"
      }
    end

    def display_export_summary(summary)
      if summary.empty?
        puts "No content blocks found to export." # rubocop:disable Rails/Output
      else
        puts "Exported content blocks to locale files:" # rubocop:disable Rails/Output
        summary.each do |locale, count|
          # rubocop:disable Rails/Output
          puts "  #{locale}: #{count} block(s) updated " \
               "in config/locales/#{locale}.yml"
          # rubocop:enable Rails/Output
        end
      end
    end

    def display_import_summary(summary)
      $stdout.puts "Import summary:"
      $stdout.puts "  Created: #{summary[:created]}"
      $stdout.puts "  Updated: #{summary[:updated]}"
      $stdout.puts "  Skipped: #{summary[:skipped]}"
      return unless summary[:errors].any?

      $stdout.puts "  Errors:"
      summary[:errors].each {|e| $stdout.puts "    - #{e}" }
    end

    def display_sync_summary(result, import_after)
      display_export_results(result[:export])
      display_import_results(result[:import], import_after) if import_after
    end

    def display_export_results(export_data)
      $stdout.puts "Sync complete!"
      $stdout.puts "\nExport summary:"
      export_data.each do |locale, count|
        $stdout.puts "  #{locale}: #{count} block(s) updated"
      end
    end

    def display_import_results(import_data, import_after)
      return unless import_after && import_data.any?

      $stdout.puts "\nImport summary:"
      $stdout.puts "  Created: #{import_data[:created]}"
      $stdout.puts "  Updated: #{import_data[:updated]}"
      $stdout.puts "  Skipped: #{import_data[:skipped]}"
    end
  end
end
