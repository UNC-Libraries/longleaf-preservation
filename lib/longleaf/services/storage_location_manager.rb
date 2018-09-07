require_relative '../models/app_fields'
require_relative '../models/storage_location'

# Manager which loads and provides access to Longleaf::StorageLocation objects
module Longleaf
  class StorageLocationManager
    AF = Longleaf::AppFields
    
    attr_reader :locations
    
    def initialize(config:)
      raise ArgumentError.new("Configuration must be provided") if config&.empty?

      @locations = Hash.new
      config[AF::LOCATIONS].each do |name, properties|
        path = properties[AF::LOCATION_PATH]
        md_path = properties[AF::METADATA_PATH]
        location = Longleaf::StorageLocation.new(name: name, path: path, metadata_path: md_path)
        
        @locations[name] = location
      end
      @locations.freeze
    end
    
    # Get the StorageLocation object which should contain the given path
    # @return [Longleaf::StorageLocation] location containing the given path
    #    or nil if the path is not contained by a registered location.
    def get_location_by_path(path)
      raise ArgumentError.new("Path parameter is required") if path.nil? || path.empty?
      @locations.each do |name, location|
        return location if path.start_with?(location.path) 
      end
      
      nil
    end
  end
end