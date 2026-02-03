require 'longleaf/events/event_names'
require 'longleaf/logging'
require 'longleaf/errors'
require 'longleaf/models/file_record'
require 'longleaf/models/service_fields'
require 'longleaf/events/register_event'
require 'longleaf/candidates/single_digest_provider'
require 'longleaf/preservation_services/rsync_replication_service'
require 'open3'

module Longleaf
  # Preservation service which performs replication of an OCFL object to one or more destinations using rsync.
  class OcflRsyncReplicationService < RsyncReplicationService
    # During a replication event, perform replication of the specified OCFL object to all configured destinations
    # as necessary.
    #
    # @param file_rec [FileRecord] record representing the OCFL object to perform the service on.
    # @param event [String] name of the event this service is being invoked by.
    # @raise [PreservationServiceError] if the rsync replication fails
    def perform(file_rec, event)
      @destinations.each do |destination|
        dest_is_storage_loc = destination.is_a?(Longleaf::StorageLocation)

        if dest_is_storage_loc
          dest_path = destination.path
        else
          dest_path = destination
        end

        logical_physical_same = file_rec.path == file_rec.physical_path
        # Determine the path to the OCFL object directory being replicated relative to its storage location
        rel_path = file_rec.storage_location.relativize(file_rec.path)

        options = @options
        if logical_physical_same
          options = options + " -R"
          # source path with . so that rsync will only create destination directories starting from that point
          # trailing slash ensures directory contents are copied
          source_path = File.join(file_rec.storage_location.path, "./#{rel_path}") + "/"
        else
          options = options + " --no-relative"
          # trailing slash ensures directory contents are copied correctly
          source_path = file_rec.physical_path + "/"
          dest_path = File.join(dest_path, rel_path) + "/"
          if (dest_is_storage_loc && destination.is_a?(Longleaf::FilesystemStorageLocation)) || !dest_is_storage_loc
            # Fill in missing parent directories for the OCFL object directory
            # Remove trailing slash for dirname calculation
            dirname = File.dirname(dest_path.chomp("/"))
            logger.debug("Creating parent dirs #{dirname} for #{file_rec.path}")
            FileUtils.mkdir_p(dirname)
          else
            raise PreservationServiceError.new(
                "Destination #{destination.name} does not currently support separate physical and logical paths")
          end
        end

        # Check that the destination is available because attempting to write
        verify_destination_available(destination, file_rec)

        logger.debug("Invoking rsync with command: #{@command} \"#{source_path}\" \"#{dest_path}\" #{options}")
        stdout, stderr, status = Open3.capture3("#{@command} \"#{source_path}\" \"#{dest_path}\" #{options}")
        raise PreservationServiceError.new("Failed to replicate #{file_rec.path} to #{dest_path}: #{stderr}") \
            unless status.success?

        logger.info("Replicated OCFL object #{file_rec.path} to destination #{dest_path}")

        # For destinations which are storage locations, register the replica with longleaf
        if dest_is_storage_loc
          register_replica(destination, rel_path, file_rec)
        end
      end
    end

    def register_replica(destination, rel_path, file_rec)
      dest_file_path = File.join(destination.path, rel_path)
      dest_file_rec = FileRecord.new(dest_file_path, destination)

      register_event = RegisterEvent.new(file_rec: dest_file_rec,
          app_manager: @app_manager,
          force: true,
          digest_provider: SingleDigestProvider.new(nil))
      register_event.perform
    end
  end
end
