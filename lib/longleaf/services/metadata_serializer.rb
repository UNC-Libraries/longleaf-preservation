require 'yaml'
require_relative '../models/metadata_record'
require_relative '../models/md_fields'

# Service which serializes MetadataRecord objects
module Longleaf
  class MetadataSerializer
    MDF = Longleaf::MDFields
    
    # Serialize the contents of the provided metadata record to the specified path
    #
    # @param metadata [MetadataRecord] metadata record to serialize. Required.
    # @param file_path [String] path to write the file to. Required.
    # @param format [String] format to serialize the metadata in. Default is 'yaml'.
    def self.write(metadata:, file_path:, format: 'yaml')
      raise ArgumentError.new('metadata parameter must be a MetadataRecord') \
          unless metadata.class == Longleaf::MetadataRecord
      
      case format
      when 'yaml'
        content = to_yaml(metadata)
      else
        raise ArgumentError.new('Invalid serialization format #{format} specified')
      end
      
      File.write(file_path, content)
    end
    
    # @param metadata [MetadataRecord] metadata record to transform
    # @return [String] a yaml representation of the provided MetadataRecord
    def self.to_yaml(metadata)
      props = to_hash(metadata)
      props.to_yaml
    end
    
    def self.to_hash(metadata)
      props = Hash.new
      
      data = Hash.new.merge(metadata.properties)
      data[MDF::REGISTERED_TIMESTAMP] = metadata.registered unless metadata.registered.nil?
      data[MDF::DEREGISTERED_TIMESTAMP] = metadata.deregistered unless metadata.deregistered.nil?
      data[MDF::CHECKSUMS] = metadata.checksums unless metadata.checksums&.empty?
      
      props[MDF::DATA] = data
      
      services = Hash.new
      metadata.list_services.each do |name|
        service = metadata.service(name)
        service[MDF::STALE_REPLICAS] = service.stale_replicas unless service.stale_replicas.nil?
        service[MDF::SERVICE_TIMESTAMP] = service.timestamp unless service.timestamp.nil?
        service[MDF::RUN_NEEDED] = service.run_needed unless service.run_needed.nil?
        services[name] = service.properties
      end
      
      props[MDF::SERVICES] = services
      
      props
    end
  end
end