require 'longleaf/services/service_manager'
require 'longleaf/events/event_names'
require 'longleaf/errors'
require 'longleaf/logging'
require 'time'

module Longleaf
  # Iterator for getting file candidates which have services which need to be run.
  # Implementation uses metadata files directly from the filesystem for determinations
  # about service status.
  class ServiceCandidateFilesystemIterator
    include Longleaf::Logging

    def initialize(file_selector, event, app_config, force = false)
      @file_selector = file_selector
      @event = event
      @app_config = app_config
      @force = force
    end

    # Get the file record for the next candidate which needs services run which match the
    # provided file_selector
    # @return [FileRecord] file record of the next candidate with services needing to be run,
    # or nil if there are no more candidates.
    def next_candidate
      loop do
        next_path = @file_selector.next_path
        return nil if next_path.nil?

        logger.debug("Evaluating candidate #{next_path}")
        storage_loc = @app_config.location_manager.get_location_by_path(next_path)
        file_rec = FileRecord.new(next_path, storage_loc)

        # Skip over unregistered files
        if !file_rec.metadata_present?
          logger.debug("Ignoring unregistered file #{next_path}")
          next
        end

        @app_config.md_manager.load(file_rec)

        # Return the file record if it needs any services run
        return file_rec if needs_run?(file_rec)
      end
    end

    # Iterate through the candidates in this object and execute the provided block with each
    # candidate. A block is required.
    def each
      file_rec = next_candidate
      until file_rec.nil?
        yield file_rec

        file_rec = next_candidate
      end
    end

    private
    # Returns true if the file record contains any services which need to be run
    def needs_run?(file_rec)
      md_rec = file_rec.metadata_record
      storage_loc = file_rec.storage_location
      service_manager = @app_config.service_manager

      # File is not a valid candidate for services if it is deregistered, unless performing cleanup
      if @event != EventNames::CLEANUP && md_rec.deregistered?
        logger.debug("Skipping deregistered file: #{file_rec.path}")
        return false
      end

      expected_services = service_manager.list_services(
          location: storage_loc.name,
          event: @event)

      # When in force mode, candidate needs a run as long as there are any services configured for it.
      if @force && expected_services.length > 0
        logger.debug("Forcing run needed for file: #{file_rec.path}")
        return true
      end

      expected_services.each do |service_name|
        if service_manager.service_needed?(service_name, md_rec)
          logger.debug("Service #{service_name} needed for file: #{file_rec.path}")
          return true
        end
      end

      logger.debug("Run not needed for file: #{file_rec.path}")
      # No services needed to be run for this file
      false
    end
  end
end
