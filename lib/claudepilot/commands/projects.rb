# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Projects < BaseCommand
      self.command_name = :projects
      description 'List Claude Code projects'

      flag :json, description: 'Output as JSON'

      def run(*)
        projects_dir = ClaudeSession::CLAUDE_DIR
        unless File.directory?(projects_dir)
          if options[:json]
            puts '[]'
          else
            puts 'No Claude projects found (~/.claude/projects/ does not exist).'.light_black
          end
          return
        end

        sessions = Tmux.sessions
        store = SessionStore.load
        enriched = sessions.map do |s|
          status = ProcessHealth.check(s)
          meta = store[s[:name]] || {}
          s.merge(status: status, dir: meta['dir'], label: meta['label'],
                  claude_session_id: meta['claude_session_id'])
        end

        known = ProjectStore.known_paths

        entries = Dir.children(projects_dir)
          .select { |e| File.directory?(File.join(projects_dir, e)) }
          .map { |encoded| build_project(projects_dir, encoded, enriched, known) }
          .compact
          .sort_by { |p| p[:last_activity] || Time.at(0) }
          .reverse

        if options[:json]
          puts JSON.pretty_generate(entries.map { |p|
            {
              path: p[:path],
              name: p[:name],
              conversation_count: p[:conversation_count],
              last_activity: p[:last_activity]&.iso8601,
              total_size_bytes: p[:total_size_bytes],
              has_memory: p[:has_memory],
              path_exists: p[:path_exists],
              sessions: p[:sessions].map { |s|
                { name: s[:short_name], label: s[:label], status: s[:status] }
              },
            }
          })
          return
        end

        if entries.empty?
          puts 'No Claude projects found.'.light_black
          return
        end

        print_projects_table(entries)
      end

      private

      def build_project(projects_dir, encoded, enriched_sessions, known_paths)
        dir = File.join(projects_dir, encoded)

        jsonl_files = Dir.glob(File.join(dir, '*.jsonl'))
        return nil if jsonl_files.empty? && !File.directory?(File.join(dir, 'memory'))

        newest_mtime = jsonl_files.map { |f| File.mtime(f) }.max
        total_size = jsonl_files.sum { |f| File.size(f) }

        memory_dir = File.join(dir, 'memory')
        has_memory = File.directory?(memory_dir) && !Dir.glob(File.join(memory_dir, '*')).empty?

        known = known_paths[encoded]
        if known
          actual_path = known[:path]
          path_exists = File.directory?(actual_path)
        else
          actual_path = PathResolver.resolve_encoded_path(encoded)
          path_exists = File.directory?(actual_path)
        end

        matching = enriched_sessions.select { |s| s[:dir] == actual_path }

        name = known&.dig(:custom_name) || File.basename(actual_path)

        {
          path: actual_path,
          name: name,
          conversation_count: jsonl_files.length,
          last_activity: newest_mtime,
          total_size_bytes: total_size,
          has_memory: has_memory,
          path_exists: path_exists,
          sessions: matching,
        }
      end

      def print_projects_table(projects)
        rows = projects.map do |p|
          session_info = if p[:sessions].empty?
                           "\u2014".light_black
                         else
                           p[:sessions].map { |s|
                             s[:short_name].colorize(Formatter.status_color(s[:status]))
                           }.join(', ')
                         end

          memory_badge = p[:has_memory] ? 'yes'.cyan : 'no'.light_black
          activity = p[:last_activity] ? Formatter.time_ago(p[:last_activity]) : "\u2014".light_black
          size_mb = format('%.1fM', p[:total_size_bytes] / 1_000_000.0)

          [
            p[:name].bold,
            p[:conversation_count].to_s,
            size_mb,
            memory_badge,
            activity,
            session_info,
            abbreviate_path(p[:path]).light_black,
          ]
        end

        Formatter.table(rows, headers: %w[PROJECT CONVOS SIZE MEMORY ACTIVITY SESSIONS PATH])
      end
    end
  end
end
