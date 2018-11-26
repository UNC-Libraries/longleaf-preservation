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
    
    # Gets a list of ServiceDefinition objects which match the given criteria
    # @param location [String] name of the location to lookup
    # @param event [String] name of the preservation event taking place
    # @return [Array] a list of ServiceDefinition objects associated with the location,
    #    or an empty list if no services match the criteria
    def list_service_definitions(location: nil, event: nil)
      service_names = @mapping_manager.list_services(location)
      defs = service_names.collect { |name| @definition_manager.services[name] }
      defs.select { |definition| applicable_for_event?(definition, event) }
    end
    
    # Determines if a service is applicable for a specific preservation event
    # @param definition [ServiceDefinition] definition of the service being evaluated
    # @param event [String] name of the event to check against
    # @return [Boolean] true if the service is applicable for the event
    def applicable_for_event?(definition, event)
      # Placeholder, waiting on preservation service implementation
      true
    end
  end
end