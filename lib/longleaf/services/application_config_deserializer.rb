require 'longleaf/services/application_config_validator'
require 'longleaf/services/application_config_manager'
require 'digest/md5'
require 'pathname'

module Longleaf
  # Deserializer for application configuration files
  class ApplicationConfigDeserializer
    AF ||= Longleaf::AppFields

    # Deserializes a valid application configuration file as a ApplicationConfigManager option
    # @param config_path [String] file path to the service and storage mapping configuration file
    # @param format [String] encoding format of the config file
    # return [ApplicationConfigManager] manager for the loaded configuration
    def self.deserialize(config_path, format: 'yaml')
      content = load_config_file(config_path)
      config = load(content, format)

      config_md5 = Digest::MD5.hexdigest(content)

      make_paths_absolute(config_path, config)

      ApplicationConfigValidator.new(config).validate_config.raise_if_invalid
      ApplicationConfigManager.new(config, config_md5)
    end

    def self.load_config_file(config_path)
      begin
        File.read(config_path)
      rescue Errno::ENOENT
        raise Longleaf::ConfigurationError.new(
            "Configuration file #{config_path} does not exist.")
      end
    end

    # Deserialize a configuration file into a hash
    # @param content [String] the contents of the application configuration file
    # @param format [String] encoding format of the config file
    # return [Hash] hash containing the configuration
    def self.load(content, format)
      case format
      when 'yaml'
        from_yaml(content)
      else
        raise ArgumentError.new("Invalid deserialization format #{format} specified")
      end
    end

    def self.from_yaml(content)
      begin
        YAML.safe_load(content, [], [], true)
      rescue => err
        raise Longleaf::ConfigurationError.new(err)
      end
    end

    def self.make_paths_absolute(config_path, config)
      base_pathname = Pathname.new(config_path).expand_path.parent

      config[AF::LOCATIONS].each do |name, properties|
        properties[AF::LOCATION_PATH] = absolution(base_pathname, properties[AF::LOCATION_PATH])

        properties[AF::METADATA_PATH] = absolution(base_pathname, properties[AF::METADATA_PATH])
      end
    end

    def self.absolution(base_pathname, file_path)
      if file_path.nil?
        nil
      else
        path = Pathname.new(file_path)
        if path.absolute?
          path = path.expand_path.to_s
        else
          path = (base_pathname + path).to_s
        end
      end
    end

    private_class_method :load_config_file
  end
end
