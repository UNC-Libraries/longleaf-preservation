require_relative 'md_fields'
require_relative 'service_record'

# Metadata record for a single file
module Longleaf
  class MetadataRecord
    attr_reader :deregistered, :registered
    
    attr_reader :checksums
    attr_reader :properties
    
    # @param properties [Hash] initial data properties for this record
    # @param services [Hash] initial service property tree
    def initialize(properties = nil, services = nil)
      @properties = properties == nil ? Hash.new : Hash.new.merge(properties)
      # Retrieve special properties and remove them from general pool of properties
      @registered = @properties.delete(MDFields::REGISTERED_TIMESTAMP)
      @deregistered = @properties.delete(MDFields::DEREGISTERED_TIMESTAMP)
      @checksums = @properties.delete(MDFields::CHECKSUMS) || Hash.new
      
      @services = Hash.new
      unless services == nil
        services.each do |service, props|
          @services[service] = ServiceRecord.new(props) if props.class == Hash
        end
      end
    end
    
    # @return [Boolean] true if the record is deregistered
    def deregistered?
      @deregistered != nil
    end
    
    # Adds a service to this record
    #
    # @param service [String] identifier for the service being added
    # @param service_properties [Hash] properties for populating the new service
    def add_service(service, service_properties = Hash.new)
      @services[service] = ServiceRecord.new(service_properties)
    end
    
    # @param name [String] name identifier of the service to retrieve
    # @return [ServiceRecord] the ServiceRecord for the service identified by name, or nil
    def service(name)
      @services[name]
    end
    
    # @return [Array<String>] a list of name identifiers for services registered to this record
    def list_services
      @services.keys
    end
  end
end