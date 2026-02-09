# frozen_string_literal: true

module ClaudePilot
  module Commands
    class ProjectName < BaseCommand
      self.command_name = :"project-name"
      description 'Name a project'

      def run(identifier = nil, new_name = nil, *)
        if identifier.nil?
          list_named_projects
          return
        end

        abort 'Usage: claudepilot project-name <path-or-current-name> <name>' unless new_name

        path = PathResolver.resolve_project_identifier(identifier)
        abort "No project matching '#{identifier}'.".red unless path

        ProjectStore.update(path, { 'name' => new_name })
        puts "#{'✓'.green} Project #{abbreviate_path(path).light_black} named #{new_name.bold}"
      end

      private

      def list_named_projects
        projects = ProjectStore.load
        if projects.empty?
          puts 'No named projects. Usage: claudepilot project-name <path-or-current-name> <name>'.light_black
          return
        end

        puts 'Named projects:'.bold
        projects.each do |path, meta|
          next unless meta['name']
          puts "  #{meta['name'].cyan}  #{abbreviate_path(path).light_black}"
        end
      end
    end
  end
end
