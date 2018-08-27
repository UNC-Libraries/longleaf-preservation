# Record for an individual service in a file's metadata record.
module Longleaf
  class ServiceRecord
    attr_reader :properties
    
    # @param properties [Hash] initial properties for this service record
    def initialize(properties = Hash.new)
      raise ArgumentError.new("Service properties must be a hash") if properties.class != Hash
      
      @properties = properties
    end
    
    # @return [Boolean] returns the stale-replicas property
    def stale_replicas
      @properties[MDFields::STALE_REPLICAS]
    end
    
    # set the stale-replicas property
    def stale_replicas=(value)
      @properties[MDFields::STALE_REPLICAS] = value
    end
    
    # @return [String] returns the timestamp property
    def timestamp
      @properties[MDFields::SERVICE_TIMESTAMP]
    end
    
    # set the timestamp property
    def timestamp=(value)
      @properties[MDFields::SERVICE_TIMESTAMP] = value
    end
    
    # @return [Boolean] returns the run-needed property
    def run_needed
      @properties[MDFields::RUN_NEEDED]
    end
    
    # set the run-needed property
    def run_needed=(value)
      @properties[MDFields::RUN_NEEDED] = value
    end
    
    # @return the value a service property identified by key
    def [](key)
      @properties[key]
    end
    
    # set the value of a service property identified by key
    def []=(key, value)
      @properties[key] = value
    end
  end
end