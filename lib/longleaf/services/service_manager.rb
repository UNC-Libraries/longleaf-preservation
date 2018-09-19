# Manager which provides preservation service definitions based on their mappings
module Longleaf
  class ServiceManager
    
    def initialize(definitions_manager:, mappings_manager:)
      raise ArgumentError.new('Service definition manager required') if definitions_manager.nil?
      raise ArgumentError.new('Service mappings manager required') if mappings_manager.nil?
      @definitions_manager = definitions_manager
      @mappings_manager = mappings_manager
    end
    
    # Gets a list of ServiceDefinition objects which match the given criteria
    # @param location [String] name of the location to lookup
    # @return [Array] a list of ServiceDefinition objects associated with the location,
    #    or an empty list if no services match the criteria
    def list_service_definitions(location: nil)
      service_names = @mappings_manager.list_services(location)
      service_names.collect { |name| @definitions_manager.services[name] }
    end
  end
end