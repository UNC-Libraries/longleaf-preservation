require 'yaml'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'
require 'longleaf/errors'
require 'longleaf/logging'

module Longleaf
  # Service which deserializes metadata files into MetadataRecord objects
  class MetadataDeserializer
    extend Longleaf::Logging
    MDF ||= MDFields
    
    # Deserialize a file into a MetadataRecord object
    #
    # @param file_path [String] path of the file to read. Required.
    # @param format [String] format the file is stored in. Default is 'yaml'.
    def self.deserialize(file_path:, format: 'yaml', digest_algs: [])
      case format
      when 'yaml'
        md = from_yaml(file_path, digest_algs)
      else
        raise ArgumentError.new('Invalid deserialization format #{format} specified')
      end
      
      if !md || !md.is_a?(Hash) || !md.key?(MDF::DATA) || !md.key?(MDF::SERVICES)
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
    
    # Load configuration a yaml encoded configuration file
    def self.from_yaml(file_path, digest_algs)
      File.open(file_path, 'r:bom|utf-8') do |f|
        contents = f.read
        
        verify_digests(file_path, contents, digest_algs)
        
        begin
          YAML.load(contents)
        rescue => err
          raise Longleaf::MetadataError.new("Failed to parse metadata file #{file_path}: #{err.message}")
        end
      end
    end
    
    def self.verify_digests(file_path, contents, digest_algs)
      return if digest_algs.nil? || digest_algs.empty?
      
      digest_algs.each do |alg|
        if file_path.respond_to?(:path)
          path = file_path.path
        else
          path = file_path
        end
        digest_path = "#{path}.#{alg}"
        unless File.exist?(digest_path)
          logger.warn("Missing expected #{alg} digest for #{path}")
          next
        end
        
        digest = DigestHelper::start_digest(alg)
        result = digest.hexdigest(contents)
        existing_digest = IO.read(digest_path)
        
        if result == existing_digest
          logger.info("Metadata fixity check using algorithm '#{alg}' succeeded for file #{path}")
        else
          raise ChecksumMismatchError.new("Metadata digest of type #{alg} did not match the contents of #{path}:" \
              + " expected #{existing_digest}, calculated #{result}")
        end
      end
    end
  end
end