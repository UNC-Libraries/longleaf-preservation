require 'thor'
require 'yaml'
require 'longleaf/errors'
require 'longleaf/commands/validate_config_command'
require 'longleaf/commands/register_command'

module Longleaf
  class CLI < Thor
    
    desc "register", "Register files with Longleaf"
    method_option :file, :aliases => "-f", :required => true
    method_option :config, :aliases => "-c", :default => ENV['LONGLEAF_CFG']
    method_option :force, :type => :boolean, default: false
    def register()
      config_path = options[:config]
      file_paths = options[:file]&.split(/\s*,\s*/)
      
      command = Longleaf::RegisterCommand.new(config_path)
      command.execute(file_paths: file_paths, force: options[:force])
    end
    
    desc "validate_config [CONFIG_PATH]", "Validate an application configuration file"
    def validate_config(config_path)
      Longleaf::ValidateConfigCommand.new(config_path).perform
    end
  end
end