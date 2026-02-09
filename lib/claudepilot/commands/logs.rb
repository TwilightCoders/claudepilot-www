# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Logs < BaseCommand
      description 'View session output'

      option :lines, Integer, short: :n, description: 'Number of lines', default: 50
      flag :follow, short: :f, description: 'Follow output (poll)'
      flag :raw, description: 'Raw output without ANSI colors'

      argument :name, String, description: 'Session name'

      def run(name = nil, *)
        abort 'Usage: claudepilot logs <name>' unless name

        full_name = resolve_session(name)
        abort "No session matching '#{name}'.".red unless full_name

        if options[:follow]
          follow_logs(full_name)
        else
          output = Tmux.capture_pane(full_name, lines: options[:lines], raw: !options[:raw])
          if output
            output = strip_ansi(output) if options[:raw]
            puts output
          else
            abort 'Failed to capture pane output.'.red
          end
        end
      end

      private

      def follow_logs(name)
        last_output = ''
        trap('INT') { puts; exit 0 }

        loop do
          output = Tmux.capture_pane(name, lines: options[:lines], raw: !options[:raw])
          break unless output

          output = strip_ansi(output) if options[:raw]

          if output != last_output
            system('clear') || system('cls')
            puts output
            last_output = output
          end
          sleep 1
        end
      end
    end
  end
end
