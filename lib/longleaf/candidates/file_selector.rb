require 'longleaf/logging'

module Longleaf
  # Selects and allows for iteration over files which match a provided set of selection criteria
  class FileSelector
    include Longleaf::Logging
    SPECIFICITY_PATH = 'path'
    SPECIFICITY_STORAGE_LOCATION = 'storage_location'

    attr_reader :specificity

    # May only provide either file_paths or storage_locations
    def initialize(file_paths: nil, storage_locations: nil, app_config:)
      if nil_or_empty?(file_paths) && nil_or_empty?(storage_locations)
        raise ArgumentError.new("Must provide either file paths or storage locations")
      end
      if !nil_or_empty?(file_paths) && !nil_or_empty?(storage_locations)
        raise ArgumentError.new("Cannot provide both file paths and storage locations")
      end
      @app_config = app_config
      # The top level paths targeted by this selector
      @target_paths = file_paths&.map do |path|
        # Resolve relative paths against pwd
        pathname = Pathname.new(path)
        if !pathname.absolute?
          path = File.join(Dir.pwd, path)
        end
        path = File.expand_path(path)

        # adding trailing /'s to directories
        if Dir.exists?(path) && !path.end_with?('/')
          path + '/'
        else
          path
        end
      end
      # The set of storage locations to select file paths from
      @storage_locations = storage_locations
      # Validate that the selected storage locations are known
      if @storage_locations.nil?
        @specificity = SPECIFICITY_PATH
      else
        @specificity = SPECIFICITY_STORAGE_LOCATION
        locations = @app_config.location_manager.locations
        @storage_locations.each do |loc_name|
          unless locations.key?(loc_name)
            raise StorageLocationUnavailableError.new("Cannot select unknown storage location #{loc_name}.")
          end
        end
      end
    end

    # @return [Array] a list of top level paths from which files will be selected
    def target_paths
      # If starting from locations, initialize by expanding locations out to their actual paths
      if @target_paths.nil? && !@storage_locations.nil?
        @target_paths = Array.new
        @storage_locations.each do |loc_name|
          @target_paths << @app_config.location_manager.locations[loc_name].path
        end
      end

      @target_paths
    end

    # Get the next file path for this selector.
    # @return [String] an absolute path to the next file targeted by this selector,
    # or nil if no more files selected
    def next_path
      if @paths.nil?
        # Start the paths listing out from the targetted set of paths for this selector
        # In reverse order since using a LIFO structure
        @paths = target_paths.reverse
      end

      # No more paths to return
      return nil if @paths&.empty?

      # Get the most recently added path for depth first traversal of selected paths
      path = @paths.pop
      until path.nil? do
        @app_config.location_manager.verify_path_in_location(path)

        if File.exist?(path)
          if File.directory?(path)
            logger.debug("Expanding directory #{path}")
            # For a directory, add all children to file_paths
            Dir.entries(path).sort.reverse_each do |child|
              @paths << File.join(path, child) unless child == '.' or child == '..'
            end
          else
            logger.debug("Returning file #{path}")
            return path
          end
        else
          raise InvalidStoragePathError.new("File #{path} does not exist.")
        end

        # Returned path was not a suitable file, try the next path
        path = @paths.pop
      end
    end

    # Iterate through the file paths for this selector and execute the provided block with each.
    # A block is required.
    def each
      file_path = next_path
      until file_path.nil?
        yield file_path

        file_path = next_path
      end
    end

    # return [Array] a list of all storage locations being targeted by this selector
    def storage_locations
      # Determine what storage_locations are represented by the given file paths
      if @storage_locations.nil? && !@target_paths.nil?
        loc_set = Set.new
        @target_paths.each do |path|
          loc = @app_config.location_manager.get_location_by_path(path)
          loc_set.add(loc.name) unless loc.nil?
        end
        @storage_locations = loc_set.to_a
      end

      if @storage_locations.nil?
        @storage_locations = Array.new
      end

      @storage_locations
    end

    private
    def nil_or_empty?(value)
      value.nil? || value.empty?
    end
  end
end
