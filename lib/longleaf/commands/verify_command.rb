require 'longleaf/errors'
require 'longleaf/events/verify_event'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/candidates/file_selector'
require 'longleaf/candidates/service_candidate_locator'
require 'longleaf/events/event_names'
require 'longleaf/logging'

module Longleaf
  # Command for verifying files
  class VerifyCommand < AbstractCommand
    include Longleaf::Logging
    include Longleaf::EventStatusTracking
    
    def initialize(app_manager)
      @app_manager = app_manager
    end
    
    # Execute the verify command on the given parameters
    # @param file_selector [FileSelector] selector for files to verify
    # @param force [Boolean] force flag
    # @return [Integer] status code
    def execute(file_selector: nil, storage_locations: nil, force: false)
      if file_selector.nil?
        record_failure("Must provide either file paths or storage locations to verify")
        return return_status
      end

      begin
        # Perform verify events on each of the file paths provided
        candidate_locator = ServiceCandidateLocator.new(@app_manager)
        candidate_it = candidate_locator.candidate_iterator(file_selector, EventNames::VERIFY, force)
        # logger.warn("Start")
        candidate_it.each do |file_rec|
          f_path = file_rec.path
          
          logger.debug("Selected candidate #{file_rec.path} for a verify event")
          verify_event = VerifyEvent.new(file_rec: file_rec, force: force, app_manager: @app_manager)
          track_status(verify_event.perform)
        end
      rescue => err
        record_failure(EventNames::VERIFY, error: err)
      end
      
      return_status
    end
  end
end
