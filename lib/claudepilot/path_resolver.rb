# frozen_string_literal: true

module ClaudePilot
  module PathResolver
    class << self
      # Resolve a Claude project directory name (e.g. "-Users-username-...-myapp")
      # back to the actual filesystem path. The encoding is lossy: both "/" and
      # characters like "_" may have been replaced with "-". Walk the filesystem
      # greedily to find the real path.
      def resolve_encoded_path(encoded)
        parts = encoded.sub(/\A-/, '').split('-')
        current = '/'
        i = 0

        while i < parts.length
          single = parts[i]
          single_path = File.join(current, single)

          if File.exist?(single_path)
            current = single_path
            i += 1
            next
          end

          resolved = false
          if File.directory?(current)
            children = Dir.children(current)
            max_try = [parts.length - i, 8].min

            (2..max_try).each do |n|
              joined = parts[i, n].join('-')
              normalized = joined.gsub(/[-_]/, '')

              match = children.find { |c| c.gsub(/[-_]/, '') == normalized }
              if match
                current = File.join(current, match)
                i += n
                resolved = true
                break
              end
            end
          end

          unless resolved
            current = File.join(current, single)
            i += 1
          end
        end

        current
      end

      # Resolve a user-provided project identifier to its filesystem path.
      # Accepts: absolute path, relative path, basename, or custom project name.
      def resolve_project_identifier(identifier)
        expanded = File.expand_path(identifier)
        return expanded if File.directory?(expanded)

        ProjectStore.load.each do |path, meta|
          return path if meta['name'] == identifier
        end

        SessionStore.load.each do |_, meta|
          next unless meta['dir']
          return meta['dir'] if File.basename(meta['dir']) == identifier
        end

        projects_dir = ClaudeSession::CLAUDE_DIR
        if File.directory?(projects_dir)
          Dir.children(projects_dir).each do |encoded|
            next unless File.directory?(File.join(projects_dir, encoded))
            path = resolve_encoded_path(encoded)
            return path if File.basename(path) == identifier
          end
        end

        nil
      end
    end
  end
end
