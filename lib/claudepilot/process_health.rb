# frozen_string_literal: true

module ClaudePilot
  module ProcessHealth
    SHELL_COMMANDS = %w[zsh bash sh fish].freeze
    APPROVAL_PATTERNS = [
      /\bDo you want to proceed\b/i,
      /\bApprove\b/i,
      /\bAllow\b/i,
      /\bDeny\b/i,
      /\by\/n\b/i,
      /\bYes\/No\b/i,
      /\(Y\)es/,
      /\bpermission\b/i,
      /Tool Use:/,
    ].freeze

    class << self
      def check(session)
        name = session[:name]
        pane_cmd = Tmux.pane_current_command(name)
        return :dead if pane_cmd && SHELL_COMMANDS.include?(pane_cmd)

        pid = session[:pane_pid]
        return :dead unless pid > 0
        return :dead unless process_tree_has_claude?(pid)

        if waiting_for_approval?(name)
          :waiting
        elsif (Time.now - session[:activity]) < 10
          :active
        else
          :idle
        end
      end

      private

      def process_tree_has_claude?(pid)
        children, _, ok = Open3.capture3('pgrep', '-P', pid.to_s)
        return false unless ok

        children.lines.each do |child_pid|
          child_pid = child_pid.strip.to_i
          next if child_pid == 0
          comm, _, = Open3.capture3('ps', '-o', 'comm=', '-p', child_pid.to_s)
          comm = File.basename(comm.strip)
          return true if comm.match?(/\A(claude|node)\z/)
          return true if process_tree_has_claude?(child_pid)
        end

        false
      end

      def waiting_for_approval?(name)
        output = Tmux.capture_pane(name, lines: 5, raw: true)
        return false unless output
        stripped = output.gsub(/\e\[[0-9;]*m/, '')
        APPROVAL_PATTERNS.any? { |pat| stripped.match?(pat) }
      end
    end
  end
end
