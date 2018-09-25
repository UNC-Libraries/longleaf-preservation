# Manager which provides preservation service definitions based on their mappings
module Longleaf
  class ServiceManager
    
    def initialize(definition_manager:, mapping_manager:)
      raise ArgumentError.new('Service definition manager required') if definition_manager.nil?
      raise ArgumentError.new('Service mappings manager required') if mapping_manager.nil?
      @definition_manager = definition_manager
      @mapping_manager = mapping_manager
    end
    
    # Gets a list of ServiceDefinition objects which match the given criteria
    # @param location [String] name of the location to lookup
    # @return [Array] a list of ServiceDefinition objects associated with the location,
    #    or an empty list if no services match the criteria
    def list_service_definitions(location: nil)
      service_names = @mapping_manager.list_services(location)
      service_names.collect { |name| @definition_manager.services[name] }
    end
  end
end