# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Usage < BaseCommand
      description 'Show API usage and rate limits'

      flag :json, description: 'Output as JSON'

      def run(*)
        api_key = ENV['ANTHROPIC_API_KEY']
        if api_key.nil? || api_key.empty?
          abort 'ANTHROPIC_API_KEY not set.'.red
        end

        usage = PolicyLimits.fetch(api_key: api_key)

        if options[:json]
          puts JSON.pretty_generate({ usage: usage })
          return
        end

        if usage.nil?
          abort 'Failed to fetch usage data.'.red
        end

        print_usage(usage)
      end
    end
  end
end
