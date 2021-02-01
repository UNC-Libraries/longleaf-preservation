require 'longleaf/events/event_names'
require 'longleaf/logging'
require 'longleaf/errors'
require 'longleaf/models/file_record'
require 'longleaf/models/service_fields'
require 'longleaf/events/register_event'
require 'longleaf/models/storage_types'
require 'aws-sdk-s3'

module Longleaf
  # Preservation service which performs replication of a file to one or more s3 destinations.
  #
  # The service definition must contain one or more destinations, specified with the "to" property.
  # These destinations must be either a known s3 storage location. The s3 client configuration
  # is controlled by the storage location.
  #
  # Optional service configuration properties:
  # * replica_collision_policy = specifies the desired outcome if the service attempts to replicate
  #     a file which already exists at a destination. Default: "replace".
  class S3ReplicationService
    include Longleaf::Logging
    ST ||= Longleaf::StorageTypes
    SF ||= Longleaf::ServiceFields

    attr_reader :collision_policy

    # Initialize a S3ReplicationService from the given service definition
    #
    # @param service_def [ServiceDefinition] the configuration for this service
    # @param app_manager [ApplicationConfigManager] the application configuration
    def initialize(service_def, app_manager)
      @service_def = service_def
      @app_manager = app_manager

      # Set and validate the replica collision policy
      @collision_policy = @service_def.properties[SF::COLLISION_PROPERTY] || SF::DEFAULT_COLLISION_POLICY
      if !SF::VALID_COLLISION_POLICIES.include?(@collision_policy)
        raise ArgumentError.new("Service #{service_def.name} received invalid #{SF::COLLISION_PROPERTY}" \
            + " value #{@collision_policy}")
      end

      # Store and validate destinations
      replicate_to = @service_def.properties[SF::REPLICATE_TO]
      if replicate_to.nil? || replicate_to.empty?
        raise ArgumentError.new("Service #{service_def.name} must provide one or more replication destinations.")
      end
      replicate_to = [replicate_to] if replicate_to.is_a?(String)

      loc_manager = app_manager.location_manager
      # Build list of destinations, translating to storage locations when relevant
      @destinations = Array.new
      replicate_to.each do |dest|
        if loc_manager.locations.key?(dest)
          location = loc_manager.locations[dest]
          if location.type != ST::S3_STORAGE_TYPE
            raise ArgumentError.new(
                "Service #{service_def.name} specifies destination #{dest} which is not of type 's3'")
          end
          @destinations << loc_manager.locations[dest]
        else
          raise ArgumentError.new("Service #{service_def.name} specifies unknown storage location '#{dest}'" \
              + " as a replication destination")
        end
      end
    end

    # During a replication event, perform replication of the specified file to all configured destinations
    # as necessary.
    #
    # @param file_rec [FileRecord] record representing the file to perform the service on.
    # @param event [String] name of the event this service is being invoked by.
    # @raise [PreservationServiceError] if the rsync replication fails
    def perform(file_rec, event)
      if file_rec.storage_location.type == ST::FILESYSTEM_STORAGE_TYPE
        replicate_from_fs(file_rec)
      else
        raise PreservationServiceError.new("Replication from storage location of type " \
            + "#{file_rec.storage_location.type} to s3 is not supported")
      end
    end

    def replicate_from_fs(file_rec)
      # Determine the path to the file being replicated relative to its storage location
      rel_path = file_rec.storage_location.relativize(file_rec.path)

      @destinations.each do |destination|
        # Check that the destination is available before attempting to write
        verify_destination_available(destination, file_rec)

        rel_to_bucket = destination.relative_to_bucket_path(rel_path)
        file_obj = destination.s3_bucket.object(rel_to_bucket)
        begin
          file_obj.upload_file(file_rec.physical_path)
        rescue Aws::S3::Errors::BadDigest => e
          raise ChecksumMismatchError.new("Transfer to bucket '#{destination.s3_bucket.name}' failed, " \
              + "MD5 provided did not match the received content for #{file_rec.path}")
        rescue Aws::Errors::ServiceError => e
          raise PreservationServiceError.new("Failed to transfer #{file_rec.path} to bucket " \
              + "'#{destination.s3_bucket.name}': #{e.message}")
        end

        logger.info("Replicated #{file_rec.path} to destination #{file_obj.public_url}")

        # TODO register file in destination
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

    private
    def verify_destination_available(destination, file_rec)
      begin
        destination.available?
      rescue StorageLocationUnavailableError => e
        raise StorageLocationUnavailableError.new("Cannot replicate #{file_rec.path} to destination #{destination.name}: " \
            + e.message)
      end
    end
  end
end
