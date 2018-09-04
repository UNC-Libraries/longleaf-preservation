require 'pathname'
require 'set'
require_relative '../models/storage_location'
require_relative '../models/app_fields'
require_relative '../errors'

# Validates application configuration of storage locations
module Longleaf
  class StorageLocationValidator
    AF = Longleaf::AppFields
    
    # Validates configuration to ensure that it is syntactically correct and does not violate schema and uniqueness requirements
    def self.validate_config(config)
      assert("Configuration must be a hash, but a #{config.class} was provided", config.class == Hash)
      assert("Configuration must contain a root '#{AF::LOCATIONS}' key", config.key?(AF::LOCATIONS))
      locations = config[AF::LOCATIONS]
      assert("'#{AF::LOCATIONS}' must be a hash of locations", locations.class == Hash)
      
      existing_locations = Set.new
      existing_paths = Array.new
      locations.each do |name, properties|
        assert("Storage location '#{name}' must be a hash of properties", properties.class == Hash)
        assert("Storage location name '#{name}' must not be defined more than once", !existing_locations.include?(name))
        existing_locations.add(name)
        
        assert_path_property_valid(name, AF::LOCATION_PATH, properties, existing_paths)
        assert_path_property_valid(name, AF::METADATA_PATH, properties, existing_paths)
      end
    end
    
    private
    def self.assert(fail_message, assertion_passed)
      raise ConfigurationError.new(fail_message) unless assertion_passed
    end
    
    def self.assert_path_property_valid(loc_name, path_prop, properties, existing_paths)
      path = properties[path_prop]
      assert("Storage location #{name} must be a hash, but a #{properties.class} was provided", properties.class == Hash)
      assert("Storage location #{name} must specify a '#{path_prop}' property", !path.nil? && !path.empty?)
      assert("Storage location #{name} must specify an absolute path for proprety '#{path_prop}'",
          Pathname.new(path).absolute? && !path.include?('/..'))
      # Ensure paths have trailing slash to avoid matching on partial directory names
      path += '/' unless path.end_with?('/')
      # Verify that the (metadata_)path property's value is not inside of another storage location or vice versa
      existing_paths.each do |existing|
        if existing.start_with?(path) || path.start_with?(existing)
          msg = "Location '#{loc_name}' defines property #{path_prop} with value '#{path}'" \
                " which overlaps with another configured path '#{existing}'." \
                " Storage locations must not define #{AF::LOCATION_PATH} or #{AF::METADATA_PATH}" \
                " properties which are contained by another location property"
          raise ConfigurationError.new(msg)
        end
      end
      
      existing_paths << path
    end
  end
end