require 'longleaf/services/application_config_validator'
require 'longleaf/services/application_config_manager'

# Deserializer for application configuration files
module Longleaf
  class ApplicationConfigDeserializer
    
    # Deserializes a valid application configuration file as a ApplicationConfigManager option
    # @param config_path [String] file path to the application configuration file
    # @param format [String] encoding format of the config file
    # return [Longleaf::ApplicationConfigManager] manager for the loaded configuration
    def self.deserialize(config_path, format: 'yaml')
      config = load(config_path, format: format)
      
      Longleaf::ApplicationConfigValidator.validate(config)
      Longleaf::ApplicationConfigManager.new(config)
    end
    
    # Deserialize a configuration file into a hash
    # @param config_path [String] file path to the application configuration file
    # @param format [String] encoding format of the config file
    # return [Hash] hash containing the configuration
    def self.load(config_path, format: 'yaml')
      case format
      when 'yaml'
        from_yaml(config_path)
      else
        raise ArgumentError.new('Invalid deserialization format #{format} specified')
      end
    end
    
    private
    def self.from_yaml(config_path)
      begin
        YAML.load_file(config_path)
      rescue Errno::ENOENT => err
        raise Longleaf::ConfigurationError.new(
            "Configuration file #{config_path} does not exist.")
      rescue => err
        raise Longleaf::ConfigurationError.new(err)
      end
    end
  end
end