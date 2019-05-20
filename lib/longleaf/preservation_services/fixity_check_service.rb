require 'longleaf/events/event_names'
require 'longleaf/models/service_fields'
require 'longleaf/logging'
require 'longleaf/helpers/digest_helper'
require 'set'

module Longleaf
  # Preservation service which performs one or more fixity checks on a file based on the configured list
  # of digest algorithms. It currently supports 'md5', 'sha1', 'sha2', 'sha256', 'sha384', 'sha512' and 'rmd160'.
  #
  # If the service encounters a file which is missing any of the digest algorithms the service is configured
  # to check, the outcome may be controlled with the 'absent_digest' property via the following values:
  #   * 'fail' - the service will raise a ChecksumMismatchError for the missing algorithm. This is the default.
  #   * 'ignore' - the service will skip calculating any algorithms not already present for the file.
  #   * 'generate' - the service will generate and store any missing digests from the set of configured algorithms.
  class FixityCheckService
    include Longleaf::Logging
    
    SUPPORTED_ALGORITHMS = ['md5', 'sha1', 'sha2', 'sha256', 'sha384', 'sha512', 'rmd160']
    
    # service configuration property indicating how to handle situations where a file does not
    # have a digest for one of the expected algorithms on record.
    ABSENT_DIGEST_PROPERTY = 'absent_digest'
    FAIL_IF_ABSENT = 'fail'
    GENERATE_IF_ABSENT = 'generate'
    IGNORE_IF_ABSENT = 'ignore'
    ABSENT_DIGEST_OPTIONS = [FAIL_IF_ABSENT, GENERATE_IF_ABSENT, IGNORE_IF_ABSENT]
    
    # Initialize a FixityCheckService from the given service definition
    #
    # @param service_def [ServiceDefinition] the configuration for this service
    # @param app_manager [ApplicationConfigManager] manager for configured storage locations
    def initialize(service_def, app_manager)
      @service_def = service_def
      @absent_digest_behavior = @service_def.properties[ABSENT_DIGEST_PROPERTY] || FAIL_IF_ABSENT
      unless ABSENT_DIGEST_OPTIONS.include?(@absent_digest_behavior)
        raise ArgumentError.new("Invalid option '#{@absent_digest_behavior}' for property #{ABSENT_DIGEST_PROPERTY} in service #{service_def.name}")
      end
      
      service_algs = service_def.properties[ServiceFields::DIGEST_ALGORITHMS]
      if service_algs.nil? || service_algs.empty?
        raise ArgumentError.new("FixityCheckService from definition #{service_def.name} requires a list of one or more digest algorithms")
      end
      
      service_algs = [service_algs] if service_algs.is_a?(String)
      
      # Store the list of digest algorithms to verify, using normalized algorithm names.
      @digest_algs = Set.new
      service_algs.each do |alg|
        normalized_alg = alg.downcase.delete('-')
        if SUPPORTED_ALGORITHMS.include?(normalized_alg)
          @digest_algs << normalized_alg
        else
          raise ArgumentError.new("Unsupported checksum algorithm '#{alg}' in definition #{service_def.name}. Supported algorithms are: #{SUPPORTED_ALGORITHMS.to_s}")
        end
      end
    end
    
    # Perform all configured fixity checks on the provided file
    #
    # @param file_rec [FileRecord] record representing the file to perform the service on.
    # @param event [String] name of the event this service is being invoked by.
    # @raise [ChecksumMismatchError] if the checksum on record does not match the generated checksum
    def perform(file_rec, event)
      path = file_rec.path
      md_rec = file_rec.metadata_record
      
      # Get the list of existing checksums for the file and normalize algorithm names
      file_digests = Hash.new
      md_rec.checksums&.each do |alg, digest|
        normalized_alg = alg.downcase.delete('-')
        if @digest_algs.include?(normalized_alg)
          file_digests[normalized_alg] = digest
        else
          logger.debug("Metadata for file #{path} contains unexpected '#{alg}' digest, it will be ignored.")
        end
      end
      
      @digest_algs.each do |alg|
        existing_digest = file_digests[alg]
        
        if existing_digest.nil?
          if @absent_digest_behavior == FAIL_IF_ABSENT
            raise ChecksumMismatchError.new("Fixity check using algorithm '#{alg}' failed for file #{path}: no existing digest of type '#{alg}' on record.")
          elsif @absent_digest_behavior == IGNORE_IF_ABSENT
            logger.debug("Skipping check of algorithm '#{alg}' for file #{path}: no digest on record.")
            next
          end
        end
        
        digest = DigestHelper::start_digest(alg)
        digest.file(path)
        generated_digest = digest.hexdigest
        
        # Store the missing checksum if using the 'generate' behavior
        if existing_digest.nil? && @absent_digest_behavior == GENERATE_IF_ABSENT
          md_rec.checksums[alg] = generated_digest
          logger.info("Generated and stored digest using algorithm '#{alg}' for file #{path}")
        else
          # Compare the new digest to the one on record
          if existing_digest == generated_digest
            logger.info("Fixity check using algorithm '#{alg}' succeeded for file #{path}")
          else
            raise ChecksumMismatchError.new("Fixity check using algorithm '#{alg}' failed for file #{path}: expected '#{existing_digest}', calculated '#{generated_digest}.'")
          end
        end
      end
    end
    
    # Determine if this service is applicable for the provided event, given the configured service definition
    #
    # @param event [String] name of the event
    # @return [Boolean] returns true if this service is applicable for the provided event
    def is_applicable?(event)
      case event
      when EventNames::PRESERVE
        true
      else
        false
      end
    end
  end
end