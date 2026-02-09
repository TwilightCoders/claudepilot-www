# frozen_string_literal: true

module ClaudePilot
  class Tool < Athena::Tool
    tool_name :claudepilot
    version ClaudePilot::VERSION
    description 'Manage tmux + Claude Code sessions'

    load_commands(File.expand_path('commands/*.rb', __dir__))
  end
end
