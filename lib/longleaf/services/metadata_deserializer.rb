require 'yaml'
require_relative '../models/metadata_record'
require_relative '../models/md_fields'
require_relative '../errors'

# Service which deserializes metadata files into MetadataRecord objects
module Longleaf
  class MetadataDeserializer
    MDF = Longleaf::MDFields
    
    # Deserialize a file into a MetadataRecord object
    #
    # @param file_path [String] path of the file to read. Required.
    # @param format [String] format the file is stored in. Default is 'yaml'.
    def self.deserialize(file_path:, format: 'yaml')
      case format
      when 'yaml'
        md = from_yaml(file_path)
      else
        raise ArgumentError.new('Invalid deserialization format #{format} specified')
      end
      
      if !md || !md.key?(MDF::DATA) || !md.key?(MDF::SERVICES)
        raise Longleaf::MetadataError.new("Invalid metadata file, did not contain data or services fields: #{file_path}")
      end
      
      data = Hash.new.merge(md[MDF::DATA])
      # Extract reserved properties for submission as separate parameters
      registered = data.delete(MDFields::REGISTERED_TIMESTAMP)
      deregistered = data.delete(MDFields::DEREGISTERED_TIMESTAMP)
      checksums = data.delete(MDFields::CHECKSUMS)
      file_size = data.delete(MDFields::FILE_SIZE)
      last_modified = data.delete(MDFields::LAST_MODIFIED)
      
      services = md[MDF::SERVICES]
      service_records = Hash.new
      unless services.nil?
        services.each do |name, props|
          raise Longleaf::MetadataError.new("Value of service #{name} must be a hash") unless props.class == Hash
          
          service_props = Hash.new.merge(props)
          
          stale_replicas = service_props.delete(MDFields::STALE_REPLICAS)
          timestamp = service_props.delete(MDFields::SERVICE_TIMESTAMP)
          run_needed = service_props.delete(MDFields::RUN_NEEDED)
          
          service_records[name] = ServiceRecord.new(
              properties: service_props,
              stale_replicas: stale_replicas,
              timestamp: timestamp,
              run_needed: run_needed)
        end
      end
      
      MetadataRecord.new(properties: data,
          services: service_records,
          registered: registered,
          deregistered: deregistered,
          checksums: checksums,
          file_size: file_size,
          last_modified: last_modified)
    end
    
    def self.from_yaml(file_path)
      YAML.load_file(file_path)
    end
  end
end