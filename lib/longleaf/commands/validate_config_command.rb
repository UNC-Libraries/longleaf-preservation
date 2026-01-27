require 'longleaf/services/application_config_deserializer'
require 'longleaf/events/event_status_tracking'

module Longleaf
  # Command for validating an application configuration file
  class ValidateConfigCommand
    include Longleaf::EventStatusTracking

    def initialize(config_path)
      @config_path = config_path
    end

    # Execute the validate command on the specified configuration yml file
    def execute
      start_time = Time.now
      logger.info('Performing validate configuration command')
      begin
        app_config_manager = Longleaf::ApplicationConfigDeserializer.deserialize(@config_path)

        location_manager = app_config_manager.location_manager
        location_manager.locations.each do |name, location|
          location.available?
        end

        validate_services(app_config_manager.service_manager)

        record_success("Application configuration passed validation: #{@config_path}")
      rescue Longleaf::ConfigurationError, Longleaf::StorageLocationUnavailableError => err
        record_failure("Application configuration invalid due to the following issue(s):\n#{err.message}", error: err)
      rescue => err
        record_failure("Failed to validate application configuration", error: err)
      end

      logger.info("Completed validate configuration command in #{Time.now - start_time}s")
      return_status
    end

    private
    # Verify that all defined services are valid and may be instantiated with the given configuration,
    # according to internal expectations.
    # @raise ConfigurationError if any services may not be instantiated
    def validate_services(service_manager)
      def_manager = service_manager.definition_manager

      def_manager.services.each do |service_name, service_def|
        begin
          service_manager.service(service_name)
        rescue => e
          raise ConfigurationError.new(e.message)
        end
      end
    end
  end
end
