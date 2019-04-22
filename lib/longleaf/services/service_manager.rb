require 'longleaf/helpers/service_date_helper'
require 'longleaf/services/service_class_cache'

module Longleaf
  # Manager which provides preservation service definitions based on their mappings
  class ServiceManager
    attr_reader :definition_manager
    attr_reader :mapping_manager
    
    # @param definition_manager [ServiceDefinitionManager] the service definition manager
    # @param mapping_manager [ServiceMappingManager] the mapping of services to locations
    # @param app_manager [ApplicationConfigManager] manager for storage locations
    def initialize(definition_manager:, mapping_manager:, app_manager:)
      raise ArgumentError.new('Service definition manager required') if definition_manager.nil?
      raise ArgumentError.new('Service mappings manager required') if mapping_manager.nil?
      raise ArgumentError.new('Storage location manager required') if app_manager.nil?
      @definition_manager = definition_manager
      @mapping_manager = mapping_manager
      @app_manager = app_manager
      @service_class_cache = ServiceClassCache.new(app_manager)
    end
    
    # Return a service instance instance for provided service name.
    # @param service_name [String] name of the service
    # @return Preservation service class for the provided name
    # @raise ArgumentError if service_name does not reference an existing service
    def service(service_name)
      raise ArgumentError.new('Service name is required') if service_name.nil? || service_name.empty?
      raise ArgumentError.new("No service with name #{service_name}") unless @definition_manager.services.key?(service_name)
      definition = @definition_manager.services[service_name]
      @service_class_cache.service_instance(definition)
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
    
    # List definitions for services which are applicable to the given criteria
    # @param location [String] name of the locations to lookup
    # @param event [String] name of the preservation event taking place
    # @return [Array] List of service definitions which match the provided criteria
    def list_service_definitions(location: nil, event: nil)
      names = list_services(location: location, event: event)
      names.map { |name| @definition_manager.services[name] }
    end
    
    # Determines if a service is applicable for a specific preservation event
    # @param service_name [String] name of the service being evaluated
    # @param event [String] name of the event to check against
    # @return [Boolean] true if the service is applicable for the event
    def applicable_for_event?(service_name, event)
      service(service_name).is_applicable?(event)
    end
    
    # Determine if a service should run for a particular file based on the service's definition and
    # the file's service related metadata.
    # @param service_name [String] name of the service being evaluated
    # @param md_rec [MetadataRecord] metadata record for the file being evaluated
    # @return [Boolean] true if the service should be run.
    def service_needed?(service_name, md_rec)
      # If service not recorded for file, then it is needed
      present_services = md_rec.list_services
      return true unless present_services.include?(service_name)
      
      service_rec = md_rec.service(service_name)
      
      return true if service_rec.run_needed
      return true if service_rec.timestamp.nil?
      
      definition = @definition_manager.services[service_name]
      
      # Check if the amount of time defined in frequency has passed since the service timestamp
      frequency = definition.frequency
      unless frequency.nil?
        service_timestamp = service_rec.timestamp
        now = ServiceDateHelper.formatted_timestamp
        
        return true if now > ServiceDateHelper.add_to_timestamp(service_timestamp, frequency)
      end
      false
    end
    
    # Perform the specified service on the file record, in the context of the specified event
    # @param service_name [String] name of the service
    # @param file_rec [FileRecord] file record to perform service upon
    # @param event [String] name of the event service is being performed within.
    def perform_service(service_name, file_rec, event)
      definition = @definition_manager.services[service_name]
      
      service = @service_class_cache.service_instance(definition)
      service.perform(file_rec, event)
    end
  end
end