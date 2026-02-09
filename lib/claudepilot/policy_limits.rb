# frozen_string_literal: true

module ClaudePilot
  module PolicyLimits
    API_URL = 'https://api.anthropic.com/api/claude_code/policy_limits'
    TIMEOUT = 3

    RATE_LIMIT_LABELS = {
      'five_hour'        => 'session limit',
      'seven_day'        => 'weekly limit',
      'seven_day_opus'   => 'Opus limit',
      'seven_day_sonnet' => 'Sonnet limit',
      'overage'          => 'extra usage',
    }.freeze

    class << self
      def fetch(api_key: nil)
        api_key ||= ENV['ANTHROPIC_API_KEY']
        return nil if api_key.nil? || api_key.empty?

        uri = URI(API_URL)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.open_timeout = TIMEOUT
        http.read_timeout = TIMEOUT

        request = Net::HTTP::Get.new(uri)
        request['x-api-key'] = api_key
        request['anthropic-version'] = '2023-06-01'

        response = http.request(request)
        return nil unless response.code == '200'

        body = JSON.parse(response.body)
        parse_restrictions(body['restrictions'] || {})
      rescue StandardError
        nil
      end

      def format_usage(limits)
        return nil unless limits && !limits.empty?

        limits.map do |limit|
          pct = limit[:utilization] ? (limit[:utilization] * 100).floor : nil
          label = RATE_LIMIT_LABELS[limit[:type]] || limit[:type]
          resets = limit[:resets_at] ? format_reset_time(limit[:resets_at]) : nil

          parts = []
          parts << "#{pct}% of #{label}" if pct
          parts << "resets #{resets}" if resets
          parts.join(' · ')
        end
      end

      private

      def parse_restrictions(restrictions)
        return [] if restrictions.empty?

        restrictions.map do |type, data|
          {
            type: type,
            allowed: data['allowed'],
            utilization: data['utilization'],
            resets_at: data['resets_at'] || data['resetsAt'],
            status: data['status'],
          }
        end
      end

      def format_reset_time(timestamp_ms)
        time = Time.at(timestamp_ms.to_f / 1000)
        zone = time.strftime('%Z')
        hour = time.strftime('%-I%P')
        "#{hour} (#{zone})"
      end
    end
  end
end
