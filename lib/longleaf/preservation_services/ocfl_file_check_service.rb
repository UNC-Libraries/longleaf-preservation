require 'longleaf/events/event_names'
require 'longleaf/helpers/ocfl_helper'
require 'longleaf/logging'

module Longleaf
  # Preservation service which validates the files in an OCFL object using filesystem information
  # compared against total file counts, total file sizes, and most recent modification timestamp.
  class OcflFileCheckService
    include Longleaf::Logging

    # Initialize a OcflFileCheckService from the given service definition
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

      logger.debug("Performing OCFL file information check of #{file_path}")

      if !File.exist?(phys_path)
        raise PreservationServiceError.new("OCFL directory does not exist: #{phys_path}")
      end

      total_size, file_count, last_modified = OcflHelper.summarized_file_info(phys_path)

      if file_count != md_rec.file_count
        raise PreservationServiceError.new("File count for OCFL object #{phys_path} does not match the expected value: registered = #{md_rec.file_count} files, actual = #{file_count} files")
      end

      if total_size != md_rec.file_size
        raise PreservationServiceError.new("File size for OCFL object #{phys_path} does not match the expected value: registered = #{md_rec.file_size} bytes, actual = #{total_size} bytes")
      end

      if last_modified != md_rec.last_modified
        raise PreservationServiceError.new("Last modified timestamp for OCFL object #{phys_path} does not match the expected value: registered = #{md_rec.last_modified}, actual = #{last_modified}")
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
