# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Label < BaseCommand
      self.command_name = :label
      description 'Set a friendly label on a session'

      argument :name, String, description: 'Session name'
      argument :label, String, description: 'Label text'

      def run(name = nil, label = nil, *)
        abort 'Usage: claudepilot label <session> <label>' unless name && label

        full_name = resolve_session(name)
        abort "No session matching '#{name}'.".red unless full_name

        SessionStore.update(full_name, { 'label' => label })
        puts "#{'✓'.green} Labeled #{name.bold} as #{label.cyan}"
      end
    end
  end
end
