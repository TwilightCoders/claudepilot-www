# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Config < BaseCommand
      self.command_name = :config
      description 'View or set configuration'

      def run(key = nil, *value_parts)
        value = value_parts.join(' ') if value_parts.any?

        if key.nil?
          show_config
        elsif value.nil?
          get_config(key)
        else
          set_config(key, value)
        end
      end

      private

      def show_config
        config = ConfigStore.load
        settings = config['settings']
        session_count = config['sessions'].length

        puts "Configuration (#{CONFIG_FILE})".bold
        puts

        if settings.empty?
          puts 'No settings configured.'.light_black
        else
          puts 'Settings:'.bold
          settings.each do |k, v|
            if v.is_a?(Hash)
              puts "  #{k.cyan}:"
              v.each { |sk, sv| puts "    #{sk.ljust(18)} #{sv}" }
            else
              puts "  #{k.ljust(20).cyan} #{v}"
            end
          end
        end

        puts
        puts "#{'Sessions:'.light_black} #{session_count} stored"
        puts
        puts "#{'Edit:'.light_black} claudepilot config <key> <value>"
        puts "#{'Tmux:'.light_black} claudepilot tmux-setup"
      end

      def get_config(key)
        val = ConfigStore.settings[key]
        if val
          puts val
        else
          exit 1
        end
      end

      def set_config(key, value)
        ConfigStore.update_settings({ key => value })
        puts "#{'✓'.green} Set #{key.cyan} = #{value}"
      end
    end
  end
end
