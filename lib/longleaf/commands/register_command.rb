require 'longleaf/services/application_config_deserializer'
require 'longleaf/events/register_event'
require 'longleaf/events/register_ocfl_event'
require 'longleaf/models/file_record'
require 'longleaf/events/event_names'
require 'longleaf/events/event_status_tracking'
require 'longleaf/models/md_fields'
require 'longleaf/candidates/ocfl_file_selector'

module Longleaf
  # Command for registering files with longleaf
  class RegisterCommand
    include Longleaf::EventStatusTracking

    def initialize(app_manager)
      @app_manager = app_manager
    end

    # Execute the register command on the given parameters
    # @param file_selector [FileSelector] selector for files to register
    # @param force [Boolean] force flag
    # @param digest_provider [ManifestDigestProvider] object which provides digests for files being registered
    # @param physical_provider [PhysicalPathProvider] object which provides physical paths for files being registered
    # @return [Integer] status code
    def execute(file_selector:, force: false, digest_provider: nil, physical_provider: nil)
      start_time = Time.now
      logger.info('Performing register command')
      ocfl_mode = file_selector.is_a?(Longleaf::OcflFileSelector)
      begin
        # Perform register events on each of the file paths provided
        loop do
          f_path = file_selector.next_path
          break if f_path.nil?

          storage_location = @app_manager.location_manager.get_location_by_path(f_path)

          phys_path = physical_provider.get_physical_path(f_path)
          object_type = ocfl_mode ? MDFields::OCFL_TYPE : nil
          file_rec = FileRecord.new(f_path, storage_location, nil, phys_path, object_type: object_type)

          if ocfl_mode
            register_event = RegisterOcflEvent.new(file_rec: file_rec, force: force, app_manager: @app_manager,
              digest_provider: digest_provider)
          else
            register_event = RegisterEvent.new(file_rec: file_rec, force: force, app_manager: @app_manager,
              digest_provider: digest_provider)
          end
          track_status(register_event.perform)
        end
      rescue InvalidStoragePathError, StorageLocationUnavailableError => err
        record_failure(EventNames::REGISTER, nil, err.message)
      rescue => err
        record_failure(EventNames::REGISTER, error: err)
      end

      logger.info("Completed register command in #{Time.now - start_time}s")
      return_status
    end
  end
end
