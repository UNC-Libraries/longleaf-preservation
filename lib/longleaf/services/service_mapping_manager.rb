require 'longleaf/models/app_fields'
require 'longleaf/models/service_definition'

module Longleaf
  # Manager which loads and provides access to location to service mappings
  class ServiceMappingManager
    AF ||= Longleaf::AppFields

    # @param config [Hash] has representation of the application configuration
    def initialize(config)
      raise ArgumentError.new("Configuration must be provided") if config.nil? || config.empty?

      mappings_config = config[AF::SERVICE_MAPPINGS]
      raise ArgumentError.new("Service mappings configuration must be provided") if mappings_config.nil?

      @loc_to_services = Hash.new

      mappings_config.each do |mapping|
        locations = mapping[AF::LOCATIONS]
        services = mapping[AF::SERVICES]

        locations = [locations] if locations.is_a?(String)
        services = [services] if services.is_a?(String)

        locations.each do |loc_name|
          @loc_to_services[loc_name] = Array.new unless @loc_to_services.key?(loc_name)

          service_set = @loc_to_services[loc_name]
          if services.is_a?(String)
            service_set.push(services)
          else
            service_set.concat(services)
          end
        end
      end

      @loc_to_services.each { |loc, services| services.uniq! }
      @loc_to_services.freeze
    end

    # Gets a list of service names associated with the given location
    # @param loc_name [String] name of the location to lookup
    # @return [Array] a list of service names associated with the location
    def list_services(loc_name)
      @loc_to_services[loc_name] || []
    end
  end
end
