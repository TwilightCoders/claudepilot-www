# frozen_string_literal: true

module ClaudePilot
  module ClaudeSession
    CLAUDE_DIR = File.expand_path('~/.claude/projects')

    class << self
      def project_dir_for(working_dir)
        working_dir.gsub('/', '-')
      end

      def latest_session_id(working_dir)
        proj = project_dir_for(working_dir)
        dir = File.join(CLAUDE_DIR, proj)
        return nil unless File.directory?(dir)

        jsonl_files = Dir.glob(File.join(dir, '*.jsonl'))
        return nil if jsonl_files.empty?

        newest = jsonl_files.max_by { |f| File.mtime(f) }
        return nil unless newest

        File.basename(newest, '.jsonl')
      end

      def detect_new_session_id(working_dir, after:)
        proj = project_dir_for(working_dir)
        dir = File.join(CLAUDE_DIR, proj)
        return nil unless File.directory?(dir)

        jsonl_files = Dir.glob(File.join(dir, '*.jsonl'))
        jsonl_files.select! { |f| File.mtime(f) > after }
        return nil if jsonl_files.empty?

        newest = jsonl_files.max_by { |f| File.mtime(f) }
        File.basename(newest, '.jsonl')
      end
    end
  end
end
