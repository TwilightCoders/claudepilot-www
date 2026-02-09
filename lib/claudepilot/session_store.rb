# frozen_string_literal: true

module ClaudePilot
  module SessionStore
    class << self
      def load
        ConfigStore.load['sessions']
      end

      def save(sessions)
        data = ConfigStore.load
        data['sessions'] = sessions
        ConfigStore.save(data)
      end

      def get(name)
        load[name]
      end

      def set(name, meta)
        data = load
        data[name] = meta
        save(data)
      end

      def update(name, updates)
        data = load
        data[name] ||= {}
        data[name].merge!(updates)
        save(data)
      end

      def delete(name)
        data = load
        data.delete(name)
        save(data)
      end

      def rename(old_name, new_name)
        data = load
        return false unless data.key?(old_name)
        data[new_name] = data.delete(old_name)
        save(data)
        true
      end

      def cleanup(active_names)
        data = load
        data.select! { |name, _| active_names.include?(name) }
        save(data)
      end
    end
  end
end
