require 'longleaf/events/event_names'
require 'longleaf/logging'

module Longleaf
  # Preservation service which validates a file using current filesystem information compared against the
  # last registered details for that file. Checks using file name, size and last modified timestamp.
  class FileCheckService
    include Longleaf::Logging

    # Initialize a FileCheckService from the given service definition
    #
    # @param service_def [ServiceDefinition] the configuration for this service
    # @param app_manager [ApplicationConfigManager] manager for configured storage locations
    def initialize(service_def, app_manager)
      @service_def = service_def
      @app_manager = app_manager
    end

    # Perform file information check.
    #
    # @param file_rec [FileRecord] record representing the file to perform the service on.
    # @param event [String] name of the event this service is being invoked by.
    # @raise [PreservationServiceError] if the file system information does not match the stored details
    def perform(file_rec, event)
      file_path = file_rec.path
      phys_path = file_rec.physical_path
      md_rec = file_rec.metadata_record

      logger.debug("Performing file information check of #{file_path}")

      if !File.exist?(phys_path)
        raise PreservationServiceError.new("File does not exist: #{phys_path}")
      end

      file_size = File.size(phys_path)
      if file_size != md_rec.file_size
        raise PreservationServiceError.new("File size for #{phys_path} does not match the expected value: registered = #{md_rec.file_size} bytes, actual = #{file_size} bytes")
      end

      last_modified = File.mtime(phys_path).utc.iso8601(3)
      if last_modified != md_rec.last_modified
        raise PreservationServiceError.new("Last modified timestamp for #{phys_path} does not match the expected value: registered = #{md_rec.last_modified}, actual = #{last_modified}")
      end
    end

    # Determine if this service is applicable for the provided event, given the configured service definition
    #
    # @param event [String] name of the event
    # @return [Boolean] returns true if this service is applicable for the provided event
    def is_applicable?(event)
      case event
      when EventNames::PRESERVE
        true
      else
        false
      end
    end
  end
end
