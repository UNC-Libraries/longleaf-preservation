module Longleaf
  # Record for an individual service in a file's metadata record.
  class ServiceRecord
    attr_reader :properties
    attr_accessor :stale_replicas, :timestamp, :run_needed
    attr_accessor :failure_timestamp

    # @param properties [Hash] initial properties for this service record
    # @param stale_replicas [Boolean] whether there are any stale replicas from this service
    # @param timestamp [String] timestamp when this service last ran or was initialized
    # @param run_needed [Boolean] flag indicating that this service should be run at the next available opportunity
    def initialize(properties: Hash.new, stale_replicas: false, timestamp: nil, run_needed: false)
      raise ArgumentError.new("Service properties must be a hash") if properties.class != Hash

      @properties = properties
      @timestamp = timestamp
      @stale_replicas = stale_replicas
      @run_needed = run_needed
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
