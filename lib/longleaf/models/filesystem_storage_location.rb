require 'longleaf/models/storage_location'
require 'longleaf/models/storage_types'

module Longleaf
  # A storage location in a local filesystem
  class FilesystemStorageLocation < StorageLocation
    # @param name [String] the name of this storage location
    # @param config [Hash] hash containing the configuration options for this location
    # @param md_loc [MetadataLocation] metadata location associated with this storage location
    def initialize(name, config, md_loc)
      super(name, config, md_loc)
      @path += File::SEPARATOR unless @path.end_with?(File::SEPARATOR)
    end

    # @return the storage type for this location
    def type
      StorageTypes::FILESYSTEM_STORAGE_TYPE
    end

    # Get that absolute path to the file associated with the provided metadata path
    # @param md_path [String] metadata file path
    # @raise [ArgumentError] if the md_path is not in this storage location
    # @return [String] the path for the file associated with this metadata
    def get_path_from_metadata_path(md_path)
      raise ArgumentError.new("A file_path parameter is required") if md_path.nil? || md_path.empty?

      rel_path = @metadata_location.relative_file_path_for(md_path)

      File.join(@path, rel_path)
    end

    # Checks that the path and metadata path defined in this location are available
    # @raise [StorageLocationUnavailableError] if the storage location is not available
    def available?
      raise StorageLocationUnavailableError.new("Path does not exist or is not a directory: #{@path}")\
          unless Dir.exist?(@path)
      @metadata_location.available?
    end

    # Get the file path relative to this location
    # @param file_path [String] file path
    # @return the file path relative to this location
    # @raise [ArgumentError] if the file path is not contained by this location
    def relativize(file_path)
      return file_path if Pathname.new(file_path).relative?

      raise ArgumentError.new("Metadata path must be contained by this location") if !file_path.start_with?(@path)

      file_path.sub(@path, "")
    end
  end
end
