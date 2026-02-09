# frozen_string_literal: true

module ClaudePilot
  module ConfigStore
    class << self
      def load
        migrate_legacy_config if needs_migration?

        return default_config unless File.exist?(CONFIG_FILE)
        data = JSON.parse(File.read(CONFIG_FILE), symbolize_names: false)

        data['settings'] ||= {}
        data['sessions'] ||= {}
        data['projects'] ||= {}
        data
      rescue JSON::ParserError
        default_config
      end

      def save(data)
        File.write(CONFIG_FILE, JSON.pretty_generate(data) + "\n")
      end

      def settings
        load['settings']
      end

      def update_settings(updates)
        data = load
        data['settings'].merge!(updates)
        save(data)
      end

      private

      def default_config
        {
          'settings' => {},
          'sessions' => {},
          'projects' => {}
        }
      end

      def needs_migration?
        !File.exist?(CONFIG_FILE) && File.exist?(LEGACY_SESSIONS_FILE)
      end

      def migrate_legacy_config
        return unless File.exist?(LEGACY_SESSIONS_FILE)

        legacy_sessions = JSON.parse(File.read(LEGACY_SESSIONS_FILE))
        new_config = {
          'settings' => {},
          'sessions' => legacy_sessions
        }
        save(new_config)

        backup = "#{LEGACY_SESSIONS_FILE}.backup"
        FileUtils.mv(LEGACY_SESSIONS_FILE, backup)
        $stderr.puts "Migrated sessions from #{LEGACY_SESSIONS_FILE} to #{CONFIG_FILE}"
        $stderr.puts "Backup saved to #{backup}"
      rescue => e
        $stderr.puts "Warning: Failed to migrate legacy config: #{e.message}"
      end
    end
  end
end
