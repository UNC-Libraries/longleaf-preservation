require 'longleaf/candidates/file_selector'
require 'longleaf/logging'

module Longleaf
  # FileSelector subclass for selecting OCFL objects
  class OcflFileSelector < FileSelector
    include Longleaf::Logging

    OCFL_OBJECT_MARKERS = ['0=ocfl_object_1.1', '0=ocfl_object_1.0'].freeze

    # Get the next logical file path for this selector.
    # Overrides parent to return directories that are OCFL objects rather than expanding them
    # @return [String] an absolute path to the next OCFL object directory targeted by this selector,
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
        physical_path = @physical_provider.get_physical_path(path)
        separate_logical = physical_path != path
        if separate_logical
          @app_config.location_manager.verify_path_in_location(physical_path)
        end

        if File.directory?(physical_path)
            if separate_logical
                raise InvalidStoragePathError.new("Cannot specify physical path to a directory: #{physical_path}")
            end

            # Check if this directory is an OCFL object
            if ocfl_object?(physical_path)
                logger.debug("Returning OCFL object directory #{path}")
                return path
            else
                logger.warn("Skipping #{path} - not an OCFL object")
            end
        else
            if File.exist?(physical_path)
                raise InvalidStoragePathError.new("File #{physical_path} is not a directory, only directories can be provided for OCFL.")
            else
                raise InvalidStoragePathError.new("File #{physical_path} does not exist.")
            end
        end

        # Returned path was not a suitable file, try the next path
        path = @paths.pop
      end
    end

    private

    # Check if a directory is an OCFL object by looking for version marker files
    # @param dir_path [String] path to the directory to check
    # @return [Boolean] true if the directory contains an OCFL object marker file
    def ocfl_object?(dir_path)
      OCFL_OBJECT_MARKERS.any? { |marker| File.exist?(File.join(dir_path, marker)) }
    end
  end
end
