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
    
    # Determine if a service should run for a particular file based on the service's definition and
    # the file's service related metadata.
    # @param definition [ServiceDefinition] definition of the service being evaluated
    # @param md_rec [MetadataRecord] metadata record for the file being evaluated
    # @return [Boolean] true if the service should be run.
    def service_needed?(definition, md_rec)
      def_name = definition.name
      # If service not recorded for file, then it is needed
      present_services = md_rec.list_services
      return true unless present_services.include?(def_name)
      
      service_rec = md_rec.service(def_name)
      
      return true if service_rec.run_needed
      return true if service_rec.timestamp.nil?
      
      # Check if the amount of time defined in frequency has passed since the service timestamp
      frequency = definition.frequency
      unless frequency.nil?
        service_timestamp = service_rec.timestamp
        now = Time.now.iso8601.to_s
        
        return true if now > ServiceDateHelper.add_to_timestamp(service_timestamp, frequency)
      end
      false
    end
  end
end