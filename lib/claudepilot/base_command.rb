# frozen_string_literal: true

module ClaudePilot
  class BaseCommand < Athena::Command
    self.abstract_class = true

    protected

    def resolve_session(name)
      full_name = "#{SESSION_PREFIX}#{name}"
      return full_name if Tmux.session_exists?(full_name)

      sessions = Tmux.sessions
      matches = sessions.select { |s| s[:short_name].include?(name) }

      case matches.length
      when 0
        nil
      when 1
        matches.first[:name]
      else
        $stderr.puts "Multiple sessions match '#{name}':".yellow
        matches.each { |m| $stderr.puts "  #{m[:short_name]}" }
        nil
      end
    end

    def auto_name(dir)
      base = File.basename(dir).downcase.gsub(/[^a-z0-9_-]/, '-').gsub(/-+/, '-')
      base = 'session' if base.empty?

      candidate = base
      counter = 1
      while Tmux.session_exists?("#{SESSION_PREFIX}#{candidate}")
        counter += 1
        candidate = "#{base}-#{counter}"
      end
      candidate
    end

    def abbreviate_path(path)
      home = File.expand_path('~')
      path.sub(/\A#{Regexp.escape(home)}/, '~')
    end

    def strip_ansi(text)
      text.gsub(/\e\[[0-9;]*[A-Za-z]/, '')
    end

    def print_usage(usage)
      if usage.nil? || usage.empty?
        puts "  #{'Usage:'.bold}    #{'No active limits'.green}"
        return
      end

      formatted = PolicyLimits.format_usage(usage)
      puts "  #{'Usage:'.bold}"
      formatted.each do |line|
        limit = usage[formatted.index(line)]
        pct = limit[:utilization] ? (limit[:utilization] * 100).floor : 0
        color = if pct >= 90 then :red
                elsif pct >= 70 then :yellow
                else :green
                end
        puts "    #{line.colorize(color)}"
      end
    end

    def recreate_session(name, full_name, meta)
      dir = meta['dir'] || '.'
      sid = meta['claude_session_id']
      preflight = meta['preflight'] || ConfigStore.settings['default_preflight']

      puts "Recreating #{name.bold} with bound Claude session..."

      claude_cmd_parts = []
      if preflight.nil?
        claude_cmd_parts << 'source ~/bin/claudenv &&'
      else
        claude_cmd_parts << 'source ~/.zsh/.zshrc &&'
        claude_cmd_parts << preflight + ' &&'
      end
      claude_cmd_parts << "claude --resume #{sid}"
      claude_cmd = claude_cmd_parts.join(' ')

      shell_cmd = %(zsh -c '#{claude_cmd}')

      _, err, ok = Tmux.new_session(full_name, dir: dir, cmd: shell_cmd)
      unless ok
        abort "Failed to create session: #{err}".red
      end

      meta['created_at'] = Time.now.iso8601
      SessionStore.set(full_name, meta)

      sleep 1.5

      unless Tmux.session_exists?(full_name)
        abort "Session created but exited immediately. Check that Claude session #{sid[0..7]}... is valid.".red
      end

      Tmux.run('send-keys', '-t', full_name, 'C-l')
      sleep 0.2

      Tmux.attach(full_name)
    end

    def detect_claude_session_id(full_name, dir, before_create)
      Thread.new do
        sleep 3
        5.times do
          sid = ClaudeSession.detect_new_session_id(dir, after: before_create)
          if sid
            SessionStore.update(full_name, { 'claude_session_id' => sid })
            break
          end
          sleep 2
        end
      end
      sleep 0.1
    end
  end
end
