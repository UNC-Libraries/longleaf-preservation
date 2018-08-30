# Record for an individual service in a file's metadata record.
module Longleaf
  class ServiceRecord
    attr_reader :properties
    attr_accessor :stale_replicas, :timestamp, :run_needed
    
    # @param properties [Hash] initial properties for this service record
    def initialize(properties = Hash.new)
      raise ArgumentError.new("Service properties must be a hash") if properties.class != Hash
      
      @properties = properties.nil? ? Hash.new : Hash.new.merge(properties)
      @stale_replicas = @properties.delete(MDFields::STALE_REPLICAS)
      @timestamp = @properties.delete(MDFields::SERVICE_TIMESTAMP)
      @run_needed = @properties.delete(MDFields::RUN_NEEDED)
    end
    
    # @return the value of a service property identified by key
    def [](key)
      @properties[key]
    end
    
    # set the value of a service property identified by key
    def []=(key, value)
      @properties[key] = value
    end
  end
end