# frozen_string_literal: true

require 'zeitwerk'
require 'athena'
require 'json'
require 'open3'
require 'fileutils'
require 'time'
require 'net/http'
require 'uri'

module ClaudePilot
  LOADER = Zeitwerk::Loader.new.tap do |loader|
    loader.tag = 'claudepilot'
    loader.inflector.inflect('claudepilot' => 'ClaudePilot')
    loader.ignore(File.expand_path('claudepilot/constants.rb', __dir__))
    loader.ignore(File.expand_path('claudepilot/version.rb', __dir__))
    loader.push_dir(File.expand_path('..', __FILE__))
    loader.setup
  end
end

require_relative 'claudepilot/version'
require_relative 'claudepilot/constants'
