# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Resume < BaseCommand
      self.command_name = :resume
      description 'Attach to a session'

      argument :name, String, description: 'Session name'

      def run(name = nil, *)
        abort 'Usage: claudepilot resume <name>' unless name

        full_name = resolve_session(name)

        if full_name
          puts "Attaching to #{full_name.delete_prefix(SESSION_PREFIX).bold}..."
          Tmux.attach(full_name)
          return
        end

        full_name = "#{SESSION_PREFIX}#{name}"
        meta = SessionStore.get(full_name)

        if meta && meta['claude_session_id']
          recreate_session(name, full_name, meta)
        else
          abort "No session matching '#{name}'.".red
        end
      end
    end
  end
end
