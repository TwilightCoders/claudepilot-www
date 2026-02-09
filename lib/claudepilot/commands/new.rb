# frozen_string_literal: true

module ClaudePilot
  module Commands
    class New < BaseCommand
      self.command_name = :new
      description 'Create and attach to a Claude session'

      option :dir, String, short: :d, description: 'Working directory'
      flag :resume, short: :r, description: 'Smart resume (attach/recreate/import)'
      option :session_id, String, description: 'Claude session ID to bind'
      option :label, String, short: :l, description: 'Friendly label for this session'
      flag :force, short: :f, description: 'Overwrite existing session without prompting'
      flag :detach, description: 'Create session but do not attach'
      option :preflight, String, description: 'Command to run before claude'
      option :claude_args, String, description: 'Extra args for claude command'

      argument :name, String, description: 'Session name', required: false

      def run(name = nil, *)
        dir = File.expand_path(options[:dir] || '.')

        unless File.directory?(dir)
          abort "Directory does not exist: #{dir}".red
        end

        name ||= auto_name(dir)
        full_name = "#{SESSION_PREFIX}#{name}"
        existing_meta = SessionStore.get(full_name)
        stored_id = existing_meta&.dig('claude_session_id')
        tmux_alive = Tmux.session_exists?(full_name)
        session_id_arg = options[:session_id]
        claude_args = options[:claude_args] ? options[:claude_args].split : []

        # Check for rebinding: --session-id <new-id> when a different ID is already bound
        if session_id_arg && stored_id && session_id_arg != stored_id
          short_old = stored_id[0..7]
          short_new = session_id_arg[0..7]
          unless options[:force]
            unless Formatter.confirm?("'#{name}' is bound to #{short_old}... Rebind to #{short_new}...?")
              puts 'Aborted.'
              return
            end
          end
          if tmux_alive
            mobile_name = "#{full_name}#{MOBILE_SUFFIX}"
            Tmux.kill_session(mobile_name) if Tmux.session_exists?(mobile_name)
            Tmux.kill_session(full_name)
            tmux_alive = false
          end
        end

        # -r: if tmux session is alive (and not rebinding), just attach
        if options[:resume] && tmux_alive
          puts "Attaching to #{name.bold}..."
          Tmux.attach(full_name)
          return
        end

        # Session exists but no -r: prompt or force
        if tmux_alive
          unless options[:force]
            unless Formatter.confirm?("Session '#{name}' already exists. Overwrite?")
              puts 'Aborted.'
              return
            end
          end
          mobile_name = "#{full_name}#{MOBILE_SUFFIX}"
          Tmux.kill_session(mobile_name) if Tmux.session_exists?(mobile_name)
          Tmux.kill_session(full_name)
        end

        # -r: tmux is dead but we have a stored binding — recreate
        if options[:resume] && !session_id_arg
          if stored_id
            return recreate_session(name, full_name, existing_meta)
          end
        end

        # Resolve session ID: explicit arg > stored binding > latest in dir
        session_id = session_id_arg || stored_id
        if options[:resume] && !session_id
          session_id = ClaudeSession.latest_session_id(dir)
          unless session_id
            $stderr.puts "No previous Claude session in #{abbreviate_path(dir)}. Starting fresh.".light_black
          end
        end

        before_create = Time.now

        # Use provided preflight, or fall back to default setting
        preflight_cmd = options[:preflight] || ConfigStore.settings['default_preflight']

        claude_cmd_parts = []
        if preflight_cmd.nil?
          claude_cmd_parts << 'source ~/bin/claudenv &&'
        else
          claude_cmd_parts << 'source ~/.zsh/.zshrc &&'
          claude_cmd_parts << preflight_cmd + ' &&'
        end
        claude_cmd_parts << 'claude'
        claude_cmd_parts += ['--resume', session_id] if session_id
        claude_cmd_parts += claude_args unless claude_args.empty?
        claude_cmd = claude_cmd_parts.join(' ')

        shell_cmd = %(zsh -c '#{claude_cmd}')

        _, err, ok = Tmux.new_session(full_name, dir: dir, cmd: shell_cmd)
        unless ok
          abort "Failed to create session: #{err}".red
        end

        meta = {
          'dir' => dir,
          'claude_args' => claude_args,
          'created_at' => Time.now.iso8601,
        }
        meta['label'] = options[:label] if options[:label]
        meta['claude_session_id'] = session_id if session_id
        meta['preflight'] = preflight_cmd if preflight_cmd

        SessionStore.set(full_name, meta)

        detect_claude_session_id(full_name, dir, before_create) unless session_id

        puts "#{'✓'.green} Session #{name.bold} created in #{dir.cyan}"
        puts "  Claude session: #{session_id.light_black}" if session_id
        puts "  Label: #{options[:label].cyan}" if options[:label]

        if options[:detach]
          puts "  Attach with: #{"claudepilot resume #{name}".light_black}"
        else
          sleep 0.5
          Tmux.attach(full_name)
        end
      end
    end
  end
end
