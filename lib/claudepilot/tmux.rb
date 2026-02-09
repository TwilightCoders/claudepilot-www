# frozen_string_literal: true

module ClaudePilot
  module Tmux
    DELIM = '|||'

    class << self
      def run(*args)
        cmd = ['tmux'] + args
        out, err, status = Open3.capture3(*cmd)
        [out.strip, err.strip, status.success?]
      end

      def running?
        _, _, ok = run('list-sessions')
        ok
      end

      def sessions
        fmt = %w[
          session_name session_windows session_created
          session_attached session_activity pane_pid
        ].map { |f| "\#{#{f}}" }.join(DELIM)

        out, _, ok = run('list-sessions', '-F', fmt)
        return [] unless ok

        out.lines.map { |line|
          parts = line.strip.split(DELIM)
          next if parts.length < 6
          name, windows, created, attached, activity, pane_pid = parts
          next unless name.start_with?(SESSION_PREFIX)
          next if name.end_with?(MOBILE_SUFFIX)

          mobile_name = "#{name}#{MOBILE_SUFFIX}"
          local_clients = attached_clients(name)
          remote_clients = session_exists?(mobile_name) ? attached_clients(mobile_name) : 0

          {
            name: name,
            short_name: name.delete_prefix(SESSION_PREFIX),
            windows: windows.to_i,
            created: Time.at(created.to_i),
            attached: attached.to_i > 0,
            attached_clients: local_clients,
            remote_clients: remote_clients,
            activity: Time.at(activity.to_i),
            pane_pid: pane_pid.to_i,
          }
        }.compact
      end

      def session_exists?(name)
        _, _, ok = run('has-session', '-t', name)
        ok
      end

      def new_session(name, dir:, cmd:)
        args = ['new-session', '-d', '-s', name, '-x', '220', '-y', '50']
        args += ['-c', dir] if dir
        args += [cmd]
        out, err, ok = run(*args)

        apply_session_style(name) if ok

        [out, err, ok]
      end

      def apply_session_style(name)
        settings = ConfigStore.settings
        tmux = settings['tmux'] || {}

        if tmux['status_left']
          run('set-option', '-t', name, 'status-left', tmux['status_left'])
        end

        if tmux['status_right']
          run('set-option', '-t', name, 'status-right', tmux['status_right'])
        end

        if tmux['status_left_length']
          run('set-option', '-t', name, 'status-left-length', tmux['status_left_length'].to_s)
        end

        if tmux['status_right_length']
          run('set-option', '-t', name, 'status-right-length', tmux['status_right_length'].to_s)
        end

        if tmux['status_style']
          run('set-option', '-t', name, 'status-style', tmux['status_style'])
        end
      end

      def kill_session(name)
        run('kill-session', '-t', name)
      end

      def attach(name)
        exec('tmux', 'attach-session', '-t', name)
      end

      def capture_pane(name, lines: 100, raw: false)
        args = ['capture-pane', '-t', name, '-p', '-S', "-#{lines}"]
        args << '-e' unless raw
        out, _, ok = run(*args)
        ok ? out : nil
      end

      def pane_current_command(name)
        out, _, ok = run('display-message', '-t', name, '-p', '#{pane_current_command}')
        ok ? out.strip : nil
      end

      def pane_pid(name)
        out, _, ok = run('display-message', '-t', name, '-p', '#{pane_pid}')
        ok ? out.strip.to_i : nil
      end

      def attached_clients(name)
        out, _, ok = run('list-clients', '-t', name)
        return 0 unless ok
        out.lines.count
      end
    end
  end
end
