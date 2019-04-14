require 'longleaf/services/system_config_manager'
require 'longleaf/errors'

module Longleaf
  # Deserializer for longleaf system configuration files
  class SystemConfigDeserializer
    
    # Deserializes a valid system configuration file as a SystemConfigManager option
    # @param config_path [String] file path to the system configuration file
    # @param app_config_manager [ApplicationConfigManager] application configuration
    # @param format [String] encoding format of the config file
    # return [SystemConfigManager] manager for the loaded configuration
    def self.deserialize(config_path, app_config_manager, format: 'yaml')
      # Return default system config manager if no config was provided
      return SystemConfigManager.new(nil, app_config_manager) if config_path.nil?
      
      config = load(config_path, format: format)
    
      SystemConfigManager.new(config, app_config_manager)
    end
    
    private
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
    
    def self.from_yaml(config_path)
      begin
        YAML.load_file(config_path)
      rescue Errno::ENOENT => err
        raise Longleaf::ConfigurationError.new(
            "System configuration file #{config_path} does not exist.")
      rescue => err
        raise Longleaf::ConfigurationError.new(err)
      end
    end
  end
end