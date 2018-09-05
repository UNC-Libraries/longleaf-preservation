require 'thor'
require 'yaml'
require_relative 'errors'
require_relative '../longleaf'
require_relative 'services/application_config_validator'

module Longleaf
  class CLI < Thor
    
    desc "register", "Register files with Longleaf"
    def register()
      puts "Register files"
    end
    
    desc "validate_config [CONFIG_PATH]", "Validate an application configuration file"
    def validate_config(config_path)
      begin
        config = YAML.load_file(config_path)
      rescue Errno::ENOENT => err
        puts "Cannot load application configuration, file #{config_path} does not exist."
        return
      rescue => err
        puts "Failed to load application configuration due to the following reason:"
        puts err.message
        return
      end
      
      begin
        Longleaf::ApplicationConfigValidator.validate(config)
        puts "Success, application configuration passed validation: #{config_path}"
      rescue Longleaf::ConfigurationError, Longleaf::StorageLocationUnavailableError => err
        puts "Application configuration invalid due to the following issue:"
        puts err.message
      rescue => err
        puts "Failed to validate application configuration:"
        puts err.message
        puts err.backtrace
      end
    end
  end
end