require 'thor'
require 'yaml'
require 'longleaf/errors'
require 'longleaf/commands/validate_config_command'

module Longleaf
  class CLI < Thor
    
    desc "register", "Register files with Longleaf"
    def register()
      puts "Register files"
    end
    
    desc "validate_config [CONFIG_PATH]", "Validate an application configuration file"
    def validate_config(config_path)
      Longleaf::ValidateConfigCommand.new(config_path).perform
    end
  end
end