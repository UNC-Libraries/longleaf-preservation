require 'longleaf/helpers/service_date_helper'

module Longleaf
  # Manager which provides preservation service definitions based on their mappings
  class ServiceManager
    # @param definition_manager [ServiceDefinitionManager] the service definition manager
    # @param mapping_manager [ServiceMappingManager] the mapping of services to locations
    def initialize(definition_manager:, mapping_manager:)
      raise ArgumentError.new('Service definition manager required') if definition_manager.nil?
      raise ArgumentError.new('Service mappings manager required') if mapping_manager.nil?
      @definition_manager = definition_manager
      @mapping_manager = mapping_manager
    end
    
    # List the names of services which are applicable to the given criteria
    # @param location [String] name of the locations to lookup
    # @param event [String] name of the preservation event taking place
    # @return [Array] a list of service names which match the provided criteria
    def list_services(location: nil, event: nil)
      service_names = @mapping_manager.list_services(location)
      if !event.nil?
        # Filter service names down by event
        service_names.select{ |name| applicable_for_event?(name, event) }
      else
        service_names
      end
    end
    
    # Determines if a service is applicable for a specific preservation event
    # @param service_name [String] name of the service being evaluated
    # @param event [String] name of the event to check against
    # @return [Boolean] true if the service is applicable for the event
    def applicable_for_event?(service_name, event)
      # Placeholder, waiting on preservation service implementation
      true
    end
  end
end