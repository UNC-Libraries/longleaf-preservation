require 'longleaf/errors'
require 'longleaf/events/event_status_tracking'
require 'longleaf/events/preserve_event'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/candidates/file_selector'
require 'longleaf/candidates/service_candidate_locator'
require 'longleaf/events/event_names'
require 'longleaf/logging'

module Longleaf
  # Command for preserving files
  class PreserveCommand
    include Longleaf::Logging
    include Longleaf::EventStatusTracking

    def initialize(app_manager)
      @app_manager = app_manager
    end

    # Execute the preserve command on the given parameters
    # @param file_selector [FileSelector] selector for files to preserve
    # @param force [Boolean] force flag
    # @return [Integer] status code
    def execute(file_selector:, force: false)
      start_time = Time.now
      logger.info('Performing preserve command')
      begin
        # Perform preserve events on each of the file paths provided
        candidate_locator = ServiceCandidateLocator.new(@app_manager)
        candidate_it = candidate_locator.candidate_iterator(file_selector, EventNames::PRESERVE, force)
        candidate_it.each do |file_rec|
          begin
            f_path = file_rec.path

            logger.debug("Selected candidate #{file_rec.path} for a preserve event")
            preserve_event = PreserveEvent.new(file_rec: file_rec, force: force, app_manager: @app_manager)
            track_status(preserve_event.perform)
          rescue InvalidStoragePathError => e
            record_failure(EventNames::PRESERVE, nil, e.message)
          end
        end
      rescue LongleafError => e
        record_failure(EventNames::PRESERVE, nil, e.message)
      rescue => err
        record_failure(EventNames::PRESERVE, error: err)
      end

      logger.info("Completed preserve command in #{Time.now - start_time}s")
      return_status
    end
  end
end
