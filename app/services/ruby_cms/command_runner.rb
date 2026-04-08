# frozen_string_literal: true

require "open3"

module RubyCms
  # Runs whitelisted Rake tasks and reads log tails for the admin Commands UI.
  class CommandRunner
    class << self
      def run_rake(task)
        raise ArgumentError, "rake task blank" if task.to_s.strip.blank?

        env = { "RAILS_ENV" => Rails.env.to_s }
        argv = ["bundle", "exec", "rake", task.to_s]
        stdout_and_stderr, status = Open3.capture2e(env, *argv, chdir: Rails.root.to_s)
        <<~TEXT.strip
          $ #{argv.join(' ')}
          (exit #{status.exitstatus})

          #{stdout_and_stderr}
        TEXT
      rescue Errno::ENOENT => e
        <<~TEXT.strip
          Failed to run command: #{e.message}
        TEXT
      end

      def tail_log(lines: 400, max_bytes: 512 * 1024)
        path = Rails.root.join("log", "#{Rails.env}.log")
        return "(Log file not found: #{path})" unless path.file?

        File.open(path, "rb") do |f|
          size = f.size
          f.seek([0, size - max_bytes].max)
          chunk = f.read
          chunk.lines.last(lines.to_i.clamp(1, 10_000)).join
        end
      rescue StandardError => e
        "(Could not read log: #{e.message})"
      end
    end
  end
end
