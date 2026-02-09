# frozen_string_literal: true

module ClaudePilot
  SESSION_PREFIX = 'claude-'
  MOBILE_SUFFIX = '-mobile'
  CONFIG_FILE = File.expand_path('~/.claudepilot.json')
  LEGACY_CONFIG_DIR = File.expand_path('~/.config/claudepilot')
  LEGACY_SESSIONS_FILE = File.join(LEGACY_CONFIG_DIR, 'sessions.json')
  CLAUDENV_PATH = File.expand_path('~/bin/claudenv')
end
