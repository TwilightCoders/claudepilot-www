# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Rename < BaseCommand
      self.command_name = :rename
      description 'Rename a session'

      argument :old_name, String, description: 'Current session name'
      argument :new_name, String, description: 'New session name'

      def run(old_name = nil, new_name = nil, *)
        abort 'Usage: claudepilot rename <old-name> <new-name>' unless old_name && new_name

        old_full = resolve_session(old_name)
        abort "No session matching '#{old_name}'.".red unless old_full

        new_full = "#{SESSION_PREFIX}#{new_name}"
        if Tmux.session_exists?(new_full)
          abort "Session '#{new_name}' already exists.".red
        end

        _, err, ok = Tmux.run('rename-session', '-t', old_full, new_full)
        unless ok
          abort "Failed to rename tmux session: #{err}".red
        end

        SessionStore.rename(old_full, new_full)

        puts "#{'✓'.green} Renamed #{old_name.bold} → #{new_name.bold}"
      end
    end
  end
end
