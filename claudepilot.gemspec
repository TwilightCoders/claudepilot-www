# frozen_string_literal: true

require_relative 'lib/claudepilot/version'

Gem::Specification.new do |spec|
  spec.name          = 'claudepilot'
  spec.version       = ClaudePilot::VERSION
  spec.authors       = ['Dale Stevens']
  spec.email         = ['dale@twilightcoders.net']

  spec.summary       = 'CLI for managing tmux + Claude Code sessions'
  spec.description   = 'Manage multiple Claude Code sessions via tmux with session binding, smart resume, and usage tracking.'
  spec.homepage      = 'https://github.com/TwilightCoders/claudepilot'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1'

  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['homepage_uri']      = spec.homepage
  spec.metadata['source_code_uri']   = spec.homepage

  spec.files         = Dir['LICENSE', 'README.md', 'lib/**/*', 'bin/*']
  spec.bindir        = 'bin'
  spec.executables   = ['claudepilot']
  spec.require_paths = ['lib']

  spec.add_dependency 'ergane', '~> 0.1'
  spec.add_dependency 'zeitwerk', '~> 2.6'
end
