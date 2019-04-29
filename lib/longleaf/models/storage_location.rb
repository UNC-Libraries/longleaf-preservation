require 'longleaf/services/metadata_serializer'

module Longleaf
  # Representation of a configured storage location
  class StorageLocation
    attr_reader :name
    attr_reader :path
    attr_reader :metadata_path
    attr_reader :metadata_digests
    
    # @param name [String] the name of this storage location
    # @param path [String] absolute path where the storage location is located
    # @param metadata_path [String] absolute path where the metadata for files in this location will be stored.
    # @param metadata_digests list of digest algorithms to use for metadata file digests in this location.
    def initialize(name:, path:, metadata_path:, metadata_digests: [])
      raise ArgumentError.new("Parameters name, path and metadata_path are required") unless name && path && metadata_path
      
      @path = path
      @path += '/' unless @path.end_with?('/')
      @name = name
      @metadata_path = metadata_path
      @metadata_path += '/' unless @metadata_path.end_with?('/')
      
      if metadata_digests.nil?
        @metadata_digests = []
      elsif metadata_digests.is_a?(String)
        @metadata_digests = [metadata_digests.downcase]
      else
        @metadata_digests = metadata_digests.map(&:downcase)
      end
      DigestHelper::validate_algorithms(@metadata_digests)
    end
    
    # Get the path for the metadata file for the given file path located in this storage location.
    # @param file_path [String] path of the file
    # @raise [ArgumentError] if the file_path is not provided or is not in this storage location.
    def get_metadata_path_for(file_path)
      raise ArgumentError.new("A file_path parameter is required") if file_path.nil? || file_path.empty?
      raise ArgumentError.new("Provided file path is not contained by storage location #{@name}: #{file_path}") \
          unless file_path.start_with?(@path)

      md_path = file_path.sub(/^#{@path}/, @metadata_path)
      # If the file_path is to a file, then add metadata suffix.
      if md_path.end_with?('/')
        md_path
      else
        md_path + MetadataSerializer::metadata_suffix
      end
    end
    
    # Get the metadata path for the provided file path located in this storage location.
    # @param md_path [String] metadata file path
    # @raise [ArgumentError] if the md_path is not in this storage location
    # @return [String] the path for the file associated with this metadata
    def get_path_from_metadata_path(md_path)
      raise ArgumentError.new("A file_path parameter is required") if md_path.nil? || md_path.empty?
      raise ArgumentError.new("Provided metadata path is not contained by storage location #{@name}: #{md_path}") \
          unless md_path&.start_with?(@metadata_path)

      file_path = md_path.sub(/^#{@metadata_path}/, @path)
      file_path.sub(/#{MetadataSerializer::metadata_suffix}$/, '')
    end
    
    # Checks that the path and metadata path defined in this location are available
    # @raise [StorageLocationUnavailableError] if the storage location is not available
    def available?
      raise StorageLocationUnavailableError.new("Path does not exist or is not a directory: #{@path}")\
          unless Dir.exist?(@path)
      raise StorageLocationUnavailableError.new("Metadata path does not exist or is not a directory: #{@metadata_path}")\
          unless Dir.exist?(@metadata_path)
    end
  end
end