# frozen_string_literal: true

module ClaudePilot
  module Commands
    class List < BaseCommand
      self.command_name = :list
      description 'List active Claude sessions'

      flag :all, short: :a, description: 'Show all sessions including dead'
      flag :json, description: 'Output as JSON'

      def run(*)
        sessions = Tmux.sessions
        store = SessionStore.load

        enriched = sessions.map do |s|
          status = ProcessHealth.check(s)
          meta = store[s[:name]] || {}
          s.merge(status: status, dir: meta['dir'], label: meta['label'],
                  claude_session_id: meta['claude_session_id'])
        end

        enriched.reject! { |s| s[:status] == :dead } unless options[:all]

        if options[:json]
          puts JSON.pretty_generate(enriched.map { |s|
            {
              name: s[:short_name],
              label: s[:label],
              status: s[:status],
              dir: s[:dir],
              claude_session_id: s[:claude_session_id],
              windows: s[:windows],
              attached: s[:attached],
              attached_clients: s[:attached_clients],
              remote_clients: s[:remote_clients],
              created: s[:created].iso8601,
              activity: s[:activity].iso8601,
            }
          })
          return
        end

        if enriched.empty?
          puts 'No active Claude sessions.'.light_black
          puts 'Start one with: claudepilot new [name] -d <dir>'.light_black
          return
        end

        has_labels = enriched.any? { |s| s[:label] }

        rows = enriched.map do |s|
          row = [s[:short_name].bold]
          row << (s[:label] ? s[:label].cyan : "\u2014".light_black) if has_labels

          local = s[:attached_clients] || 0
          remote = s[:remote_clients] || 0

          attach_info = if local > 0 && remote > 0
                          "#{("#{local} local").green}, #{("#{remote} remote").cyan}"
                        elsif local > 0
                          "#{local} local".green
                        elsif remote > 0
                          "#{remote} remote".cyan
                        else
                          'detached'.light_black
                        end

          row += [
            Formatter.status_badge(s[:status]),
            s[:dir] ? abbreviate_path(s[:dir]).light_black : "\u2014".light_black,
            attach_info,
            Formatter.time_ago(s[:activity]),
          ]
          row
        end

        headers = ['NAME']
        headers << 'LABEL' if has_labels
        headers += ['STATUS', 'DIRECTORY', 'CLIENTS', 'ACTIVITY']

        Formatter.table(rows, headers: headers)
      end
    end
  end
end
