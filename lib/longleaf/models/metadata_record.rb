require_relative 'md_fields'
require_relative 'service_record'

module Longleaf
  # Metadata record for a single file
  class MetadataRecord
    attr_reader :registered
    attr_accessor :deregistered
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
    def initialize(properties: nil, services: nil, deregistered: nil, registered: nil, checksums: nil,
          file_size: nil, last_modified: nil)
      @properties = properties || Hash.new
      @registered = registered
      @deregistered = deregistered
      @checksums = checksums || Hash.new
      @services = services || Hash.new
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
    # @return [ServiceRecord] the service added
    def add_service(name, service = ServiceRecord.new)
      raise ArgumentError.new("Value must be a ServiceRecord object when adding a service") unless service.class == Longleaf::ServiceRecord
      raise IndexError.new("Service with name '#{name}' already exists") if @services.key?(name)

      @services[name] = service
    end

    # Updates details of service record as if the service had been executed.
    # @param service_name [String] name of the service run
    # @return [ServiceRecord] the service record updated
    def update_service_as_performed(service_name)
      service_rec = service(service_name) || add_service(service_name)
      service_rec.run_needed = false
      service_rec.timestamp = ServiceDateHelper.formatted_timestamp
      service_rec
    end

    # Updates details of service record as if the service had encountered a
    # failure during execution.
    # @param service_name [String] name of the service run
    # @return [ServiceRecord] the service record updated
    def update_service_as_failed(service_name)
      service_rec = service(service_name) || add_service(service_name)
      service_rec.failure_timestamp = ServiceDateHelper.formatted_timestamp
      service_rec
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
