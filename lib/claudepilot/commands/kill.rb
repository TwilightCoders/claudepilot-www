# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Kill < BaseCommand
      self.command_name = :kill
      description 'Kill session(s)'

      flag :force, short: :f, description: 'Skip confirmation'
      flag :all, short: :a, description: 'Kill all Claude sessions'

      argument :name, String, description: 'Session name', required: false

      def run(name = nil, *)
        if options[:all]
          kill_all
        else
          abort 'Usage: claudepilot kill <name> [-f] [-a]' unless name
          kill_one(name)
        end
      end

      private

      def kill_all
        sessions = Tmux.sessions
        if sessions.empty?
          puts 'No sessions to kill.'.light_black
          return
        end

        unless options[:force]
          names = sessions.map { |s| s[:short_name] }.join(', ')
          unless Formatter.confirm?("Kill all sessions (#{names})?")
            puts 'Aborted.'
            return
          end
        end

        sessions.each do |s|
          Tmux.kill_session(s[:name])
          SessionStore.delete(s[:name])
          puts "#{'✗'.red} Killed #{s[:short_name]}"
        end
      end

      def kill_one(name)
        full_name = resolve_session(name)
        abort "No session matching '#{name}'.".red unless full_name

        short = full_name.delete_prefix(SESSION_PREFIX)
        unless options[:force]
          unless Formatter.confirm?("Kill session '#{short}'?")
            puts 'Aborted.'
            return
          end
        end

        mobile_name = "#{full_name}#{MOBILE_SUFFIX}"
        Tmux.kill_session(mobile_name) if Tmux.session_exists?(mobile_name)

        Tmux.kill_session(full_name)
        SessionStore.delete(full_name)
        puts "#{'✗'.red} Killed #{short}"
      end
    end
  end
end
