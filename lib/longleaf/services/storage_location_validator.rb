require 'pathname'
require 'longleaf/models/app_fields'
require 'longleaf/models/storage_types'
require 'longleaf/errors'
require_relative 'configuration_validator'
require 'longleaf/services/filesystem_location_validator'
require 'longleaf/services/s3_location_validator'

module Longleaf
  # Validates application configuration of storage locations
  class StorageLocationValidator < ConfigurationValidator
    AF ||= Longleaf::AppFields
    ST ||= Longleaf::StorageTypes

    @@storage_type_mappings = {
        ST::FILESYSTEM_STORAGE_TYPE => Longleaf::FilesystemLocationValidator,
        ST::S3_STORAGE_TYPE => Longleaf::S3LocationValidator
      }

    # @param config [Hash] hash containing the application configuration
    def initialize(config)
      super(config)
      @existing_paths = Array.new
    end

    protected
    # Validates configuration to ensure that it is syntactically correct and does not violate
    # schema and uniqueness requirements.
    def validate
      assert("Configuration must be a hash, but a #{@config.class} was provided", @config.class == Hash)
      assert("Configuration must contain a root '#{AF::LOCATIONS}' key", @config.key?(AF::LOCATIONS))
      locations = @config[AF::LOCATIONS]
      assert("'#{AF::LOCATIONS}' must be a hash of locations", locations.class == Hash)

      locations.each do |name, properties|
        register_on_failure do
          assert("Name of storage location must be a string, but was of type #{name.class}", name.instance_of?(String))
          assert("Storage location '#{name}' must be a hash, but a #{properties.class} was provided", properties.is_a?(Hash))

          register_on_failure { assert_path_property_valid(name, AF::LOCATION_PATH, properties, 'location') }

          assert("Metadata location must be present for location '#{name}'", properties.key?(AF::METADATA_CONFIG))
          assert_path_property_valid(name, AF::LOCATION_PATH, properties[AF::METADATA_CONFIG], 'metadata')
        end
      end

      @result
    end

    private
    def assert_path_property_valid(name, path_prop, properties, section_name)
      path = properties[path_prop]

      storage_type = properties[AF::STORAGE_TYPE] || ST::DEFAULT_STORAGE_TYPE
      type_validator = @@storage_type_mappings[storage_type]
      type_validator.validate(self, name, path_prop, section_name, path)

      # Ensure paths have trailing slash to avoid matching on partial directory names
      path += '/' unless path.end_with?('/')
      # Verify that the (metadata_)path property's value is not inside of another storage location or vice versa
      @existing_paths.each do |existing|
        if existing.start_with?(path) || path.start_with?(existing)
          msg = "Location '#{name}' defines property #{section_name} #{path_prop} with value '#{path}'" \
                " which overlaps with another configured path '#{existing}'." \
                " Storage locations must not define #{AF::LOCATION_PATH}" \
                " properties which are contained by another location property"
          fail(msg)
        end
      end

      @existing_paths << path
    end
  end
end
