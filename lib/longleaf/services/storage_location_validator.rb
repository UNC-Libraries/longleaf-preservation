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

          register_on_failure { assert_path_property_valid(name, AF::LOCATION_PATH, properties) }
          assert_path_property_valid(name, AF::METADATA_PATH, properties)
        end
      end

      @result
    end

    private
    def assert_path_property_valid(name, path_prop, properties)
      path = properties[path_prop]
      begin
        StoragePathValidator::validate(path)
      rescue InvalidStoragePathError => err
        fail("Storage location '#{name}' specifies invalid '#{path_prop}' property: #{err.message}")
      end
      assert("Storage location '#{name}' must specify a '#{path_prop}' property", !path.nil? && !path.empty?)
      assert("Storage location '#{name}' must specify an absolute path for property '#{path_prop}'",
          Pathname.new(path).absolute? && !path.include?('/..'))
      assert("Storage location '#{name}' specifies a '#{path_prop}' directory which does not exist", Dir.exist?(path))

      # Ensure paths have trailing slash to avoid matching on partial directory names
      path += '/' unless path.end_with?('/')
      # Verify that the (metadata_)path property's value is not inside of another storage location or vice versa
      @existing_paths.each do |existing|
        if existing.start_with?(path) || path.start_with?(existing)
          msg = "Location '#{name}' defines property #{path_prop} with value '#{path}'" \
                " which overlaps with another configured path '#{existing}'." \
                " Storage locations must not define #{AF::LOCATION_PATH} or #{AF::METADATA_PATH}" \
                " properties which are contained by another location property"
          fail(msg)
        end
      end

      @existing_paths << path
    end
  end
end
