require 'longleaf/models/app_fields'
require 'longleaf/models/filesystem_storage_location'
require 'longleaf/models/s3_storage_location'
require 'longleaf/models/filesystem_metadata_location'
require 'longleaf/errors'

module Longleaf
  # Manager which loads and provides access to {StorageLocation} objects
  class StorageLocationManager
    AF ||= Longleaf::AppFields

    # Hash mapping storage location names to {StorageLocation} objects
    attr_reader :locations
    # Mapping of storage types to storage location classes
    @@storage_type_mappings = {
        AF::FILESYSTEM_STORAGE_TYPE => Longleaf::FilesystemStorageLocation,
        AF::S3_STORAGE_TYPE => Longleaf::S3StorageLocation
      }
    @@metadata_type_mappings = { AF::FILESYSTEM_STORAGE_TYPE => Longleaf::FilesystemMetadataLocation }

    # @param config [Hash] has representation of the application configuration
    def initialize(config)
      raise ArgumentError.new("Configuration must be provided") if config&.empty?

      @locations = Hash.new
      config[AF::LOCATIONS].each do |name, properties|
        md_loc = instantiate_metadata_location(properties)

        @locations[name] = instantiate_storage_location(name, properties, md_loc)
      end
      @locations.freeze
    end

    # Get the {StorageLocation} object which should contain the given path
    # @return [Longleaf::StorageLocation] location containing the given path
    #    or nil if the path is not contained by a registered location.
    def get_location_by_path(path)
      raise ArgumentError.new("Path parameter is required") if path.nil? || path.empty?
      @locations.each do |name, location|
        return location if location.contains?(path)
      end

      nil
    end

    # Get the {StorageLocation} object which should contain the given metadata path
    # @return [Longleaf::StorageLocation] location containing the given metadata path
    #    or nil if the path is not contained by a registered location.
    def get_location_by_metadata_path(md_path)
      raise ArgumentError.new("Metadata path parameter is required") if md_path.nil? || md_path.empty?
      @locations.each do |name, location|
        return location if location.metadata_location.contains?(md_path)
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

    private
    def instantiate_metadata_location(loc_properties)
      m_config = loc_properties[AF::METADATA_CONFIG]
      m_type = m_config[AF::STORAGE_TYPE]
      m_type = AF::FILESYSTEM_STORAGE_TYPE if m_type.nil?

      m_class = @@metadata_type_mappings[m_type]
      raise ArgumentError.new("Unknown metadata location type #{m_type}") if m_class.nil?

      m_class.new(m_config)
    end

    def instantiate_storage_location(name, properties, md_loc)
      s_type = properties[AF::STORAGE_TYPE]
      s_type = AF::FILESYSTEM_STORAGE_TYPE if s_type.nil?

      s_class = @@storage_type_mappings[s_type]
      raise ArgumentError.new("Unknown storage location type #{s_type}") if s_class.nil?

      s_class.new(name, properties, md_loc)
    end
  end
end
