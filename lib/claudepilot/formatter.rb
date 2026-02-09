# frozen_string_literal: true

module ClaudePilot
  module Formatter
    STATUS_COLORS = {
      active:  :green,
      waiting: :yellow,
      idle:    :cyan,
      dead:    :red,
    }.freeze

    class << self
      def table(rows, headers:)
        widths = headers.map(&:length)
        rows.each do |row|
          row.each_with_index do |cell, i|
            len = visible_length(cell.to_s)
            widths[i] = len if len > (widths[i] || 0)
          end
        end

        header_line = headers.each_with_index.map { |h, i| h.ljust(widths[i]) }.join('  ')
        separator = widths.map { |w| "\u2500" * w }.join("\u2500\u2500")

        puts header_line.bold
        puts separator.light_black
        rows.each do |row|
          line = row.each_with_index.map { |cell, i|
            padding = widths[i] - visible_length(cell.to_s)
            "#{cell}#{' ' * [padding, 0].max}"
          }.join('  ')
          puts line
        end
      end

      def status_color(status)
        STATUS_COLORS[status.to_sym] || :white
      end

      def status_badge(status)
        color = status_color(status)
        status.to_s.colorize(color)
      end

      def confirm?(prompt)
        $stderr.print "#{prompt} [y/N] "
        return false unless $stdin.tty?
        answer = $stdin.gets&.strip
        answer&.match?(/\Ay(es)?\z/i)
      end

      def time_ago(time)
        seconds = (Time.now - time).to_i
        return 'just now' if seconds < 60
        return "#{seconds / 60}m ago" if seconds < 3600
        return "#{seconds / 3600}h ago" if seconds < 86400
        "#{seconds / 86400}d ago"
      end

      private

      def visible_length(str)
        str.gsub(/\e\[[0-9;]*m/, '').length
      end
    end
  end
end
