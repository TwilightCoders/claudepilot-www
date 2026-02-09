# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Status < BaseCommand
      description 'Show session health details'

      flag :json, description: 'Output as JSON'

      argument :name, String, description: 'Session name'

      def run(name = nil, *)
        abort 'Usage: claudepilot status <name>' unless name

        full_name = resolve_session(name)
        abort "No session matching '#{name}'.".red unless full_name

        session = Tmux.sessions.find { |s| s[:name] == full_name }
        abort 'Session data not found.'.red unless session

        status = ProcessHealth.check(session)
        meta = SessionStore.get(full_name) || {}
        usage = PolicyLimits.fetch

        if options[:json]
          puts JSON.pretty_generate({
            name: session[:short_name],
            full_name: full_name,
            label: meta['label'],
            status: status,
            dir: meta['dir'],
            claude_session_id: meta['claude_session_id'],
            windows: session[:windows],
            attached: session[:attached],
            pane_pid: session[:pane_pid],
            pane_command: Tmux.pane_current_command(full_name),
            created: session[:created].iso8601,
            activity: session[:activity].iso8601,
            claude_args: meta['claude_args'],
            usage: usage,
          })
          return
        end

        puts "Session: #{session[:short_name]}".bold
        puts "  Label:     #{meta['label'].cyan}" if meta['label']
        puts "  Status:    #{Formatter.status_badge(status)}"
        puts "  Directory: #{(meta['dir'] || "\u2014").cyan}"
        puts "  Claude ID: #{meta['claude_session_id'].light_black}" if meta['claude_session_id']
        puts "  Windows:   #{session[:windows]}"
        puts "  Attached:  #{session[:attached] ? 'yes'.green : 'no'}"
        puts "  Pane PID:  #{session[:pane_pid]}"
        puts "  Pane cmd:  #{Tmux.pane_current_command(full_name)}"
        puts "  Created:   #{session[:created].strftime('%Y-%m-%d %H:%M:%S')}"
        puts "  Activity:  #{Formatter.time_ago(session[:activity])}"

        if meta['claude_args'] && !meta['claude_args'].empty?
          puts "  Claude args: #{meta['claude_args'].join(' ')}"
        end

        if meta['preflight']
          puts "  Preflight:   #{meta['preflight'].light_black}"
        end

        print_usage(usage)
      end
    end
  end
end
