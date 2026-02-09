# frozen_string_literal: true

module ClaudePilot
  module Commands
    class TmuxSetup < BaseCommand
      self.command_name = :"tmux-setup"
      description 'Configure tmux status bar'

      def run(*)
        puts 'Configure tmux status bar for claudepilot sessions'.bold
        puts

        config = ConfigStore.load
        tmux = config['settings']['tmux'] || {}

        default_config = {
          'status_left' => '[#S] ',
          'status_left_length' => '40',
          'status_right' => '%H:%M %d-%b-%y',
          'status_style' => 'bg=black,fg=white'
        }

        if tmux.empty?
          puts 'No tmux config found. Apply defaults?'
          puts "  status_left: #{default_config['status_left']}".light_black
          puts "  status_left_length: #{default_config['status_left_length']}".light_black
          puts "  status_right: #{default_config['status_right']}".light_black
          puts "  status_style: #{default_config['status_style']}".light_black
          puts

          if Formatter.confirm?('Apply?')
            config['settings']['tmux'] = default_config
            ConfigStore.save(config)
            puts "#{'✓'.green} Tmux config saved"
            puts 'New sessions will use these settings'.light_black
            puts "Edit #{CONFIG_FILE} to customize".light_black
          end
        else
          puts 'Current tmux config:'.bold
          tmux.each { |k, v| puts "  #{k.ljust(20).cyan} #{v}" }
          puts
          puts "Edit #{CONFIG_FILE} to customize".light_black
          puts
          puts 'Available settings:'.bold
          puts '  status_left           Left side of status bar (use #S for session name)'
          puts '  status_left_length    Max length of left side'
          puts '  status_right          Right side of status bar'
          puts '  status_right_length   Max length of right side'
          puts "  status_style          Status bar colors (e.g., 'bg=black,fg=white')"
        end
      end
    end
  end
end
