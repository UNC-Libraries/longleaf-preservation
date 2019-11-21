require 'longleaf/models/app_fields'

module Longleaf
  # Representation of a configured storage location
  class StorageLocation
    AF ||= Longleaf::AppFields

    attr_reader :name
    attr_reader :path
    attr_reader :metadata_location

    # @param name [String] the name of this storage location
    # @param config [Hash] hash containing the configuration options for this location
    # @param md_loc [MetadataLocation] metadata location associated with this storage location
    def initialize(name, config, md_loc)
      raise ArgumentError.new("Config parameter is required") unless config
      @path = config[AF::LOCATION_PATH]
      @name = name
      raise ArgumentError.new("Parameters name, path and metadata location are required") unless @name && @path && md_loc

      @path += '/' unless @path.end_with?('/')
      @metadata_location = md_loc
    end

    # Get the path for the metadata file for the given file path located in this storage location.
    # @param file_path [String] path of the file
    # @raise [ArgumentError] if the file_path is not provided or is not in this storage location.
    def get_metadata_path_for(file_path)
      raise ArgumentError.new("A file_path parameter is required") if file_path.nil? || file_path.empty?
      raise ArgumentError.new("Provided file path is not contained by storage location #{@name}: #{file_path}") \
          unless file_path.start_with?(@path)

      rel_file_path = relativize(file_path)

      @metadata_location.metadata_path_for(rel_file_path)
    end

    # @param [String] path to check
    # @return true if the file path is contained by the path for this location
    def contains?(file_path)
      file_path.start_with?(@path)
    end
  end
end
