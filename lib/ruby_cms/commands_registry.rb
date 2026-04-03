# frozen_string_literal: true

module RubyCms
  # Host apps register runnable commands (usually Rake tasks) shown on Admin → Commands.
  module CommandsRegistry
    def registered_commands
      @registered_commands ||= []
    end

    def registered_commands=(list)
      @registered_commands = list
    end

    # Register a button-triggered command for the admin Commands screen.
    #
    # @param key [String, Symbol] Unique id (e.g. :copy_en_to_nl)
    # @param label [String] Button label
    # @param rake_task [String] Full rake task name, including args in brackets if needed
    # @param description [String, nil] Optional help text under the button
    # @param permission [Symbol] Required to run (+can?+); default +:manage_admin+
    def register_command(key:, label:, rake_task:, description: nil, permission: :manage_admin)
      k = key.to_s
      entry = {
        key: k,
        label: label.to_s,
        rake_task: rake_task.to_s,
        description: description.to_s.presence,
        permission: permission.to_sym
      }
      self.registered_commands = registered_commands.reject {|e| e[:key] == k } + [entry]
      entry
    end

    def find_command(key)
      registered_commands.find {|e| e[:key] == key.to_s }
    end
  end

  extend CommandsRegistry
end
