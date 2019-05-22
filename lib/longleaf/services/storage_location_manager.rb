require 'longleaf/models/app_fields'
require 'longleaf/models/storage_location'
require 'longleaf/errors'

module Longleaf
  # Manager which loads and provides access to {StorageLocation} objects
  class StorageLocationManager
    AF ||= Longleaf::AppFields

    # Hash mapping storage location names to {StorageLocation} objects
    attr_reader :locations

    # @param config [Hash] has representation of the application configuration
    def initialize(config)
      raise ArgumentError.new("Configuration must be provided") if config&.empty?

      @locations = Hash.new
      config[AF::LOCATIONS].each do |name, properties|
        path = properties[AF::LOCATION_PATH]
        md_path = properties[AF::METADATA_PATH]
        md_digests = properties[AF::METADATA_DIGESTS]
        location = Longleaf::StorageLocation.new(name: name,
            path: path,
            metadata_path: md_path,
            metadata_digests: md_digests)

        @locations[name] = location
      end
      @locations.freeze
    end

    # Get the {StorageLocation} object which should contain the given path
    # @return [Longleaf::StorageLocation] location containing the given path
    #    or nil if the path is not contained by a registered location.
    def get_location_by_path(path)
      raise ArgumentError.new("Path parameter is required") if path.nil? || path.empty?
      @locations.each do |name, location|
        return location if path.start_with?(location.path)
      end

      nil
    end

    # Get the {StorageLocation} object which should contain the given metadata path
    # @return [Longleaf::StorageLocation] location containing the given metadata path
    #    or nil if the path is not contained by a registered location.
    def get_location_by_metadata_path(md_path)
      raise ArgumentError.new("Metadata path parameter is required") if md_path.nil? || md_path.empty?
      @locations.each do |name, location|
        return location if md_path.start_with?(location.metadata_path)
      end

      nil
    end

    # Raises a {StorageLocationUnavailableError} if the given path is not in a known storage location,
    #    or if it is not within the expected location if provided
    # @param path [String] file path
    # @param expected_loc [String] name of the storage location which path should be contained by
    # @raise [StorageLocationUnavailableError] if the path is not in a known/expected storage location
    # @return [StorageLocation] the storage location which contains path, if it was within one.
    def verify_path_in_location(path, expected_loc = nil)
      location = get_location_by_path(path)
      if location.nil?
        raise StorageLocationUnavailableError.new("Path #{path} is not from a known storage location.")
      elsif !expected_loc.nil? && expected_loc != location.name
        raise StorageLocationUnavailableError.new("Path #{path} is not contained by storage location #{expected_loc}.")
      end
      location
    end
  end
end
