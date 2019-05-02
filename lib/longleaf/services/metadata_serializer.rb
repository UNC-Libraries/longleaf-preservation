require 'yaml'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'
require 'longleaf/helpers/digest_helper'
require 'longleaf/errors'
require 'longleaf/logging'
require 'pathname'

module Longleaf
  # Service which serializes MetadataRecord objects
  class MetadataSerializer
    extend Longleaf::Logging
    MDF ||= MDFields
    
    # Serialize the contents of the provided metadata record to the specified path
    #
    # @param metadata [MetadataRecord] metadata record to serialize. Required.
    # @param file_path [String] path to write the file to. Required.
    # @param format [String] format to serialize the metadata in. Default is 'yaml'.
    # @param digest_algs [Array] if provided, sidecar digest files for the metadata file
    #    will be generated for each algorithm.
    def self.write(metadata:, file_path:, format: 'yaml', digest_algs: [])
      raise ArgumentError.new('metadata parameter must be a MetadataRecord') \
          unless metadata.class == MetadataRecord
      
      case format
      when 'yaml'
        content = to_yaml(metadata)
      else
        raise ArgumentError.new('Invalid serialization format #{format} specified')
      end
      
      # Fill in parent directories if they do not exist
      parent_dir = Pathname(file_path).parent
      parent_dir.mkpath unless parent_dir.exist?
      
      File.write(file_path, content)
      write_digests(file_path, content, digest_algs)
    end
    
    # @param metadata [MetadataRecord] metadata record to transform
    # @return [String] a yaml representation of the provided MetadataRecord
    def self.to_yaml(metadata)
      props = to_hash(metadata)
      props.to_yaml
    end
    
    # Create a hash representation of the given MetadataRecord file
    # @param metadata [MetadataRecord] metadata record to transform into a hash
    def self.to_hash(metadata)
      props = Hash.new
      
      data = Hash.new.merge(metadata.properties)
      data[MDF::REGISTERED_TIMESTAMP] = metadata.registered if metadata.registered
      data[MDF::DEREGISTERED_TIMESTAMP] = metadata.deregistered if metadata.deregistered
      data[MDF::CHECKSUMS] = metadata.checksums unless metadata.checksums&.empty?
      data[MDF::FILE_SIZE] = metadata.file_size unless metadata.file_size.nil?
      data[MDF::LAST_MODIFIED] = metadata.last_modified if metadata.last_modified
      
      props[MDF::DATA] = data
      
      services = Hash.new
      metadata.list_services.each do |name|
        service = metadata.service(name)
        service[MDF::STALE_REPLICAS] = service.stale_replicas if service.stale_replicas
        service[MDF::SERVICE_TIMESTAMP] = service.timestamp unless service.timestamp.nil?
        service[MDF::RUN_NEEDED] = service.run_needed if service.run_needed
        services[name] = service.properties unless service.properties.empty?
      end
      
      props[MDF::SERVICES] = services
      
      props
    end
    
    # @param format [String] encoding format used for metadata file
    # @return [String] the suffix used to indicate that a file is a metadata file in the provided encoding
    # @raise [ArgumentError] raised if the provided format is not a supported metadata encoding format
    def self.metadata_suffix(format: 'yaml')
      case format
      when 'yaml'
        '-llmd.yaml'
      else
        raise ArgumentError.new('Invalid serialization format #{format} specified')
      end
    end
    
    private
    def self.write_digests(file_path, content, digests)
      return if digests.nil? || digests.empty?
      
      digests.each do |alg|
        digest_class = DigestHelper::start_digest(alg)
        result = digest_class.hexdigest(content)
        if file_path.respond_to?(:path)
          digest_path = "#{file_path.path}.#{alg}"
        else
          digest_path = "#{file_path}.#{alg}"
        end
        
        File.write(digest_path, result)
        
        self.logger.debug("Generated #{alg} digest for metadata file #{file_path}: #{result}")
      end
    end
  end
end