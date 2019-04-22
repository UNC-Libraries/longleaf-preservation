require 'longleaf/services/application_config_validator'
require 'longleaf/services/application_config_manager'
require 'digest/md5'

module Longleaf
  # Deserializer for application configuration files
  class ApplicationConfigDeserializer
    
    # Deserializes a valid application configuration file as a ApplicationConfigManager option
    # @param serv_config_path [String] file path to the service and storage mapping configuration file
    # @param sys_config_path [String] file path to the system configuration file
    # @param format [String] encoding format of the config file
    # return [ApplicationConfigManager] manager for the loaded configuration
    def self.deserialize(serv_config_path, sys_config_path = nil, format: 'yaml')
      if sys_config_path.nil?
        sys_config = nil
      else
        sys_content = load_config_file(sys_config_path)
        sys_config = load(sys_content, format)
      end
      
      content = load_config_file(serv_config_path)
      config = load(content, format)
      
      config_md5 = Digest::MD5.hexdigest(content)
    
      Longleaf::ApplicationConfigValidator.validate(config)
      Longleaf::ApplicationConfigManager.new(config, sys_config, config_md5)
    end
    
    private
    def self.load_config_file(config_path)
      begin
        File.read(config_path)
      rescue Errno::ENOENT => err
        raise Longleaf::ConfigurationError.new(
            "Configuration file #{config_path} does not exist.")
      end
    end
    
    # Deserialize a configuration file into a hash
    # @param config_path [String] file path to the application configuration file
    # @param format [String] encoding format of the config file
    # return [Hash] hash containing the configuration
    def self.load(content, format)
      case format
      when 'yaml'
        from_yaml(content)
      else
        raise ArgumentError.new('Invalid deserialization format #{format} specified')
      end
    end
    
    def self.from_yaml(content)
      begin
        YAML.load(content)
      rescue => err
        raise Longleaf::ConfigurationError.new(err)
      end
    end
  end
end