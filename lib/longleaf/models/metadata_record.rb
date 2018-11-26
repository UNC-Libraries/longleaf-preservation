require_relative 'md_fields'
require_relative 'service_record'

module Longleaf
  # Metadata record for a single file
  class MetadataRecord
    attr_reader :deregistered, :registered
    attr_reader :checksums
    attr_reader :properties
    attr_accessor :file_size, :last_modified
    
    # @param properties [Hash] initial data properties for this record
    # @param services [Hash] initial service property tree
    # @param deregistered [String] deregistered timestamp
    # @param registered [String] registered timestamp
    # @param checksums [Hash] hash of checksum values
    # @param file_size [Integer] size of file in bytes
    # @param last_modified [String] iso8601 representation of the last modified date of file
    def initialize(properties: Hash.new, services: Hash.new, deregistered: nil, registered: nil, checksums: Hash.new,
          file_size: nil, last_modified: nil)
      @properties = properties
      @registered = registered
      @deregistered = deregistered
      @checksums = checksums
      @services = services
      @file_size = file_size
      @last_modified = last_modified
    end
    
    # @return [Boolean] true if the record is deregistered
    def deregistered?
      !@deregistered.nil?
    end
    
    # Adds a service to this record
    #
    # @param name [String] identifier for the service being added
    # @param service [ServiceRecord] properties for populating the new service
    def add_service(name, service = ServiceRecord.new)
      raise ArgumentError.new("Value must be a ServiceRecord object when adding a service") unless service.class == Longleaf::ServiceRecord
      raise IndexError.new("Service with name '#{name}' already exists") if @services.key?(name)
      
      @services[name] = service
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