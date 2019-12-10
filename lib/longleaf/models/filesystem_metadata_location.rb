require 'longleaf/services/metadata_serializer'
require 'longleaf/models/metadata_location'
require 'longleaf/models/storage_types'

module Longleaf
  # A filesystem based location in which metadata associated with registered files is stored.
  class FilesystemMetadataLocation < MetadataLocation
    AF ||= Longleaf::AppFields

    def initialize(config)
      super(config)
    end

    # @return the storage type for this location
    def type
      StorageTypes::FILESYSTEM_STORAGE_TYPE
    end

    # Get the absolute path for the metadata file for the given file path located in this storage location.
    # @param file_path [String] path of the file relative its storage location
    # @return absolute path to the metadata
    # @raise [ArgumentError] if the file_path is not provided.
    def metadata_path_for(file_path)
      raise ArgumentError.new("A file_path parameter is required") if file_path.nil?
      raise ArgumentError.new("File path must be relative") if Pathname.new(file_path).absolute?

      md_path = File.join(@path, file_path)
      # If the file_path is to a file, then add metadata suffix.
      if md_path.end_with?('/')
        md_path
      else
        md_path + MetadataSerializer::metadata_suffix
      end
    end

    # Get the metadata path relative to this location
    # @param md_path [String] metadata file path
    # @return the metadata path relative to this location
    # @raise [ArgumentError] if the metadata path is not contained by this location
    def relativize(md_path)
      return md_path if Pathname.new(md_path).relative?

      raise ArgumentError.new("Metadata path must be contained by this location") if !md_path.start_with?(@path)

      md_path.sub(@path, "")
    end


    # Checks that the path defined in this metadata location are available
    # @raise [StorageLocationUnavailableError] if the metadata location is not available
    def available?
      raise StorageLocationUnavailableError.new("Metadata path does not exist or is not a directory: #{@path}")\
          unless Dir.exist?(@path)
    end
  end
end
