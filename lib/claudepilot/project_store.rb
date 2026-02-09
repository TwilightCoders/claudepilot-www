# frozen_string_literal: true

module ClaudePilot
  module ProjectStore
    class << self
      def load
        ConfigStore.load['projects']
      end

      def save(projects)
        data = ConfigStore.load
        data['projects'] = projects
        ConfigStore.save(data)
      end

      def get(path)
        load[path]
      end

      def set(path, meta)
        data = load
        data[path] = meta
        save(data)
      end

      def update(path, updates)
        data = load
        data[path] ||= {}
        data[path].merge!(updates)
        save(data)
      end

      def known_paths
        sessions = SessionStore.load
        projects = load

        by_encoded = {}
        sessions.each do |session_name, meta|
          next unless meta['dir']
          encoded = meta['dir'].gsub('/', '-')
          by_encoded[encoded] = {
            path: meta['dir'],
            session_name: session_name.delete_prefix(SESSION_PREFIX)
          }
        end

        projects.each do |path, meta|
          encoded = path.gsub('/', '-')
          by_encoded[encoded] ||= { path: path }
          by_encoded[encoded][:custom_name] = meta['name'] if meta['name']
        end

        by_encoded
      end
    end
  end
end
