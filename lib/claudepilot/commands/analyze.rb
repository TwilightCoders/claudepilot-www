# frozen_string_literal: true

module ClaudePilot
  module Commands
    class Analyze < BaseCommand
      description 'Analyze conversations by context'

      option :categories, String, description: 'Suggested categories (comma-separated)'

      argument :name_or_dir, String, description: 'Session name or directory'

      def run(name_or_dir = nil, *)
        if name_or_dir.nil?
          puts 'Usage: claudepilot analyze <session-name-or-directory> [--categories cat1,cat2,...]'.red
          puts 'Analyzes Claude Code conversations using AI and suggests how to split them.'
          return
        end

        dir = resolve_target(name_or_dir)
        return unless dir

        project_name = ClaudeSession.project_dir_for(dir)
        project_path = File.join(ClaudeSession::CLAUDE_DIR, project_name)

        unless File.directory?(project_path)
          puts "No Claude project found for #{dir}".red
          return
        end

        conversations = Dir.glob(File.join(project_path, '*.jsonl'))

        if conversations.empty?
          puts 'No conversations found.'.light_black
          return
        end

        puts "Analyzing #{conversations.length} conversations for #{File.basename(dir)}...".bold
        puts 'Using local Claude CLI to categorize conversations...'.light_black
        puts

        results = analyze_conversations_with_llm(conversations, options[:categories])

        unless results
          puts 'Failed to analyze conversations.'.red
          return
        end

        grouped = results.group_by { |r| r[:category] }

        colors = [:green, :cyan, :magenta, :yellow, :blue]
        category_colors = {}
        grouped.keys.each_with_index { |cat, i| category_colors[cat] = colors[i % colors.length] }

        grouped.each do |category, convos|
          color = category_colors[category]
          desc = convos.first[:category_desc]

          header = "#{category.to_s.upcase} (#{convos.length} conversations)"
          header += " - #{desc}" if desc
          puts
          puts header.colorize(color).bold
          puts ("\u2500" * 80).light_black

          convos.sort_by { |c| -c[:size] }.each do |c|
            size_mb = (c[:size] / 1_000_000.0).round(1)
            date = c[:mtime].strftime('%b %d %H:%M')
            puts "  #{size_mb}MB  #{date}  #{c[:file][0..20]}..."
          end
        end

        puts
        puts 'Next steps:'.bold
        puts 'After reorganizing your directories, move the conversation folders:'
        puts '  cd ~/.claude/projects/'.light_black
        grouped.keys.each do |category|
          source = project_name
          target = project_name.sub(/claudepilot$/, "claudepilot-#{category}")
          puts "  cp -r #{source} #{target}  # then remove unneeded conversations".light_black
        end
      end

      private

      def resolve_target(name_or_dir)
        full_name = "#{SESSION_PREFIX}#{name_or_dir}"
        meta = SessionStore.get(full_name)

        if meta && meta['dir']
          meta['dir']
        elsif File.directory?(File.expand_path(name_or_dir))
          File.expand_path(name_or_dir)
        else
          puts "Not found: '#{name_or_dir}' (tried as session name and directory path)".red
          nil
        end
      end

      def analyze_conversations_with_llm(conversations, categories_hint)
        require 'tempfile'

        samples = conversations.map do |file|
          content = File.read(file)
          lines = content.lines
          size = File.size(file)
          mtime = File.mtime(file)

          sample_lines = lines.first(50) + ['...'] + lines.last(50)
          sample = sample_lines.join

          {
            id: File.basename(file, '.jsonl'),
            size: size,
            mtime: mtime,
            sample: sample[0..10000]
          }
        end

        prompt = build_categorization_prompt(samples, categories_hint)

        prompt_file = Tempfile.new(['claudepilot-prompt', '.txt'])
        response_file = Tempfile.new(['claudepilot-response', '.json'])

        begin
          prompt_file.write(prompt)
          prompt_file.write("\n\nWrite your JSON response to: #{response_file.path}")
          prompt_file.close
          response_file.close

          cmd = "claude -p --no-session-persistence --model sonnet < #{prompt_file.path} > #{response_file.path} 2>&1"
          system(cmd)

          analysis_text = File.read(response_file.path).strip

          if analysis_text.empty?
            $stderr.puts 'No response from Claude CLI'.red
            return nil
          end

          if analysis_text.include?('Credit balance is too low')
            $stderr.puts 'Claude CLI: Credit balance too low'.red
            return nil
          end

          parse_llm_categorization(analysis_text, conversations)
        ensure
          prompt_file.unlink
          response_file.unlink
        end
      rescue => e
        $stderr.puts "Error: #{e.message}".red
        $stderr.puts e.backtrace.first(3).join("\n").light_black if ENV['DEBUG']
        nil
      end

      def build_categorization_prompt(samples, categories_hint)
        hint_text = if categories_hint
          "\nSuggested categories (use as hints): #{categories_hint}"
        else
          "\nDiscover the natural categories yourself."
        end

        <<~PROMPT
          I have #{samples.length} Claude Code conversation files that I need to categorize.
          These are conversations from the same project directory.#{hint_text}

          Please analyze these conversation samples and:
          1. Identify natural categories/topics (keep it to 3-5 categories max)
          2. Assign each conversation to the most appropriate category
          3. Give each category a short, clear name (1-2 words)

          Conversation samples:
          #{samples.map.with_index { |s, i|
            "Conversation #{i + 1} (ID: #{s[:id][0..7]}..., #{(s[:size] / 1_000_000.0).round(1)}MB, #{s[:mtime].strftime('%b %d')}):\n#{s[:sample][0..500]}\n---"
          }.join("\n\n")}

          IMPORTANT: Respond with ONLY valid JSON, no other text. Use this exact format:
          {
            "categories": {
              "category-name-1": "Brief description",
              "category-name-2": "Brief description"
            },
            "assignments": {
              "#{samples.first[:id][0..7]}": "category-name-1"
            }
          }

          For assignments, use the 8-character IDs shown above (e.g. "#{samples.first[:id][0..7]}").
        PROMPT
      end

      def parse_llm_categorization(response_text, conversations)
        json_text = if response_text =~ /```(?:json)?\s*(\{.*?\})\s*```/m
          $1
        elsif response_text =~ /\{.*\}/m
          $&
        end

        unless json_text
          $stderr.puts 'Could not find JSON in LLM response'.red
          $stderr.puts "Response: #{response_text[0..200]}...".light_black if ENV['DEBUG']
          return nil
        end

        data = JSON.parse(json_text)
        categories = data['categories'] || {}
        assignments = data['assignments'] || {}

        conversations.map do |file|
          id = File.basename(file, '.jsonl')
          short_id = id[0..7]
          category_name = assignments[id] || assignments[short_id] || 'uncategorized'

          {
            file: id,
            size: File.size(file),
            mtime: File.mtime(file),
            category: category_name.to_sym,
            category_desc: categories[category_name]
          }
        end
      rescue JSON::ParserError => e
        $stderr.puts "Failed to parse JSON: #{e.message}".red
        nil
      end
    end
  end
end
