require 'pathname'
require 'longleaf/models/storage_location'
require 'longleaf/models/app_fields'
require 'longleaf/errors'
require_relative 'configuration_validator'
require 'longleaf/services/storage_path_validator'

module Longleaf
  # Validates application configuration of storage locations
  class StorageLocationValidator < ConfigurationValidator
    AF ||= Longleaf::AppFields

    # Validates configuration to ensure that it is syntactically correct and does not violate
    # schema and uniqueness requirements.
    # @param config [Hash] hash containing the application configuration
    def self.validate_config(config)
      assert("Configuration must be a hash, but a #{config.class} was provided", config.class == Hash)
      assert("Configuration must contain a root '#{AF::LOCATIONS}' key", config.key?(AF::LOCATIONS))
      locations = config[AF::LOCATIONS]
      assert("'#{AF::LOCATIONS}' must be a hash of locations", locations.class == Hash)

      existing_paths = Array.new
      locations.each do |name, properties|
        assert("Name of storage location must be a string, but was of type #{name.class}", name.instance_of?(String))
        assert("Storage location '#{name}' must be a hash, but a #{properties.class} was provided", properties.is_a?(Hash))

        assert_path_property_valid(name, AF::LOCATION_PATH, properties, existing_paths)
        assert_path_property_valid(name, AF::METADATA_PATH, properties, existing_paths)
      end
    end

    def self.assert_path_property_valid(name, path_prop, properties, existing_paths)
      path = properties[path_prop]
      begin
        StoragePathValidator::validate(path)
      rescue InvalidStoragePathError => err
        raise ConfigurationError.new(
            "Storage location '#{name}' specifies invalid '#{path_prop}' property: #{err.message}")
      end
      assert("Storage location '#{name}' must specify a '#{path_prop}' property", !path.nil? && !path.empty?)
      assert("Storage location '#{name}' must specify an absolute path for property '#{path_prop}'",
          Pathname.new(path).absolute? && !path.include?('/..'))
      assert("Storage location '#{name}' specifies a '#{path_prop}' directory which does not exist", Dir.exist?(path))

      # Ensure paths have trailing slash to avoid matching on partial directory names
      path += '/' unless path.end_with?('/')
      # Verify that the (metadata_)path property's value is not inside of another storage location or vice versa
      existing_paths.each do |existing|
        if existing.start_with?(path) || path.start_with?(existing)
          msg = "Location '#{name}' defines property #{path_prop} with value '#{path}'" \
                " which overlaps with another configured path '#{existing}'." \
                " Storage locations must not define #{AF::LOCATION_PATH} or #{AF::METADATA_PATH}" \
                " properties which are contained by another location property"
          raise ConfigurationError.new(msg)
        end
      end

      existing_paths << path
    end

    private_class_method :assert_path_property_valid
  end
end
