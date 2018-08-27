require_relative 'md_fields'
require_relative 'service_record'

module Longleaf
  class MetadataRecord
    attr_reader :deregistered, :registered
    
    attr_reader :checksums
    attr_reader :properties
    
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
    
    def deregistered?
      @deregistered != nil
    end
    
    def add_service(service, service_properties = Hash.new)
      raise ArgumentError.new("Service properties must be a hash") if service_properties.class != Hash
      
      @services[service] = service_properties
    end
    
    def service(name)
      @services[name]
    end
    
    def list_services
      @services.keys
    end
  end
end