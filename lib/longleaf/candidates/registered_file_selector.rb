require 'longleaf/candidates/file_selector'
require 'longleaf/logging'

module Longleaf
  # Selects and allows for iteration over files which are registered and match a provided
  # set of selection criteria
  class RegisteredFileSelector < FileSelector
    include Longleaf::Logging

    # Get the next file path for this selector.
    # @raise [InvalidStoragePathError] if any of the selected files do not exist
    # @raise [StorageLocationUnavailableError] if any of the selected paths are not
    #    in a registered storage location.
    # @return [String] an absolute path to the next file targeted by this selector,
    #    or nil if no more files selected
    def next_path
      if @md_paths.nil?
        # Compute the starting paths by looking up the metadata paths for the provided targets,
        # in reverse order since @md_paths is a LIFO stack structure.
        @md_paths = target_paths.reverse_each.map do |file_path|
          storage_loc = @app_config.location_manager.verify_path_in_location(file_path)
          storage_loc.get_metadata_path_for(file_path)
        end
      end

      # No more paths to return
      return nil if @md_paths&.empty?

      # Get the most recently added path for depth first traversal of selected paths
      md_path = @md_paths.pop
      until md_path.nil? do
        if File.exist?(md_path)
          if File.directory?(md_path)
            logger.debug("Expanding metadata directory #{md_path}")
            # For a directory, add all children to file_paths
            Dir.entries(md_path).sort.reverse_each do |child|
              @md_paths << File.join(md_path, child) unless child == '.' or child == '..'
            end
          elsif md_path.end_with?(MetadataSerializer::metadata_suffix)
            # Convert metadata path to file path before returning
            return file_path_for_metadata(md_path)
          else
            logger.debug("Skipping non-metadata file in metadata directory #{md_path}")
          end
        else
          file_path = file_path_for_metadata(md_path)
          if File.exist?(file_path)
            raise RegistrationError.new("File #{file_path} is not registered.")
          else
            raise InvalidStoragePathError.new("File #{file_path} does not exist.")
          end
        end

        # Returned path was not a suitable file, try the next path
        md_path = @md_paths.pop
      end
    end

    private
    def file_path_for_metadata(md_path)
      storage_loc = @app_config.location_manager.get_location_by_metadata_path(md_path)
      file_path = storage_loc.get_path_from_metadata_path(md_path)
      logger.debug("Returning next file #{file_path} for metadata path #{md_path}")
      return file_path
    end
  end
end
