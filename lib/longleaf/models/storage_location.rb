module Longleaf
  class StorageLocation
    attr_reader :name
    attr_reader :path
    attr_reader :metadata_path
    
    def initialize(name:, path:, metadata_path:)
      raise ArgumentError.new("Parameters name, path and metadata_path are required") unless name && path && metadata_path
      
      @path = path
      @name = name
      @metadata_path = metadata_path
    end
    
    # Get the path for the metadata file for the given file path located in this storage location.
    # @param file_path [String] path of the file
    # @raise [ArgumentError] if the file_path is not provided or is not in this storage location.
    def get_metadata_path_for(file_path)
      raise ArgumentError.new("A file_path parameter is required") if file_path.nil? || file_path.empty?
      raise ArgumentError.new("Provided file path is not contained by storage location #{@name}: #{file_path}") \
          unless file_path.start_with?(@path)

      file_path.sub(/^#{@path}/, metadata_path)
    end
    
    # Checks that the path and metadata path defined in this location are available
    # @raise [StorageLocationUnavailableError] if the storage location is not available
    def  validator
      raise StorageLocationUnavailableError.new("Path does not exist or is not a directory: #{@path}")\
          unless Dir.exist?(@path)
      raise StorageLocationUnavailableError.new("Metadata path does not exist or is not a directory: #{@metadata_path}")\
          unless Dir.exist?(@metadata_path)
    end
  end
end