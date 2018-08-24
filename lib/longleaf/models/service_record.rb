module Longleaf
  class ServiceRecord
    attr_reader :properties
    
    def initialize(properties = Hash.new)
      @properties = properties
    end
    
    def stale_replicas
      @properties[MDFields::STALE_REPLICAS]
    end
    
    def stale_replicas=(value)
      @properties[MDFields::STALE_REPLICAS] = value
    end
    
    def timestamp
      @properties[MDFields::SERVICE_TIMESTAMP]
    end
    
    def timestamp=(value)
      @properties[MDFields::SERVICE_TIMESTAMP] = value
    end
    
    def run_needed
      @properties[MDFields::RUN_NEEDED]
    end
    
    def run_needed=(value)
      @properties[MDFields::RUN_NEEDED] = value
    end
    
    def [](key)
      @properties[key]
    end
    
    def []=(key, value)
      @properties[key] = value
    end
  end
end