require 'digest/md5'
require 'find'
require 'longleaf/events/event_names'
require 'longleaf/logging'
require 'longleaf/errors'
require 'longleaf/models/service_fields'
require 'longleaf/models/storage_types'
require 'aws-sdk-s3'

module Longleaf
  # Preservation service which replicates an OCFL object from a local OCFL storage location
  # to one or more S3 destinations.
  #
  # All files under the OCFL object directory are transferred. Files under committed version
  # directories (vN/) are skipped if they already exist in S3 since they are immutable. All other
  # files are compared by ETag to detect changes without re-uploading unchanged content.
  #
  # When the source storage location has mutable head enabled (OcflStorageLocation#mutable_head?
  # returns true), S3 objects under the mutable head extension directory
  # (extensions/0005-mutable-head/) that no longer exist locally are deleted from the destination.
  # This handles the case where a mutable head has been committed into a real version, which is
  # the only case in normal OCFL operation where object files are legitimately removed.
  #
  # The service definition must contain one or more destinations specified with the "to" property.
  # These destinations must be known S3 storage locations.
  #
  # Optional service configuration properties:
  # * replica_collision_policy = specifies the desired outcome if the service attempts to replicate
  #     a file which already exists at a destination. Default: "replace".
  class OcflS3ReplicationService
    include Longleaf::Logging

    ST ||= Longleaf::StorageTypes
    SF ||= Longleaf::ServiceFields

    attr_reader :collision_policy

    # Initialize an OcflS3ReplicationService from the given service definition
    #
    # @param service_def [ServiceDefinition] the configuration for this service
    # @param app_manager [ApplicationConfigManager] the application configuration
    def initialize(service_def, app_manager)
      @service_def = service_def
      @app_manager = app_manager

      @collision_policy = @service_def.properties[SF::COLLISION_PROPERTY] || SF::DEFAULT_COLLISION_POLICY
      unless SF::VALID_COLLISION_POLICIES.include?(@collision_policy)
        raise ArgumentError.new("Service #{service_def.name} received invalid #{SF::COLLISION_PROPERTY}" \
            + " value #{@collision_policy}")
      end

      replicate_to = @service_def.properties[SF::REPLICATE_TO]
      if replicate_to.nil? || replicate_to.empty?
        raise ArgumentError.new("Service #{service_def.name} must provide one or more replication destinations.")
      end
      replicate_to = [replicate_to] if replicate_to.is_a?(String)

      # Gather and verify s3 destinations
      loc_manager = app_manager.location_manager
      @destinations = Array.new
      replicate_to.each do |dest|
        if loc_manager.locations.key?(dest)
          location = loc_manager.locations[dest]
          if location.type != ST::S3_STORAGE_TYPE
            raise ArgumentError.new(
                "Service #{service_def.name} specifies destination #{dest} which is not of type 's3'")
          end
          @destinations << location
        else
          raise ArgumentError.new("Service #{service_def.name} specifies unknown storage location '#{dest}'" \
              + " as a replication destination")
        end
      end
    end

    # Replicate the OCFL object to all configured S3 destinations.
    #
    # @param file_rec [FileRecord] record representing the OCFL object directory to replicate.
    # @param event [String] name of the event this service is being invoked by.
    # @raise [PreservationServiceError] if replication fails
    def perform(file_rec, event)
      unless file_rec.storage_location.type == ST::OCFL_STORAGE_TYPE
        raise PreservationServiceError.new("OcflS3ReplicationService only supports replication from OCFL " \
            + "storage locations, but source '#{file_rec.storage_location.name}' is of type " \
            + "'#{file_rec.storage_location.type}'")
      end

      phys_path = file_rec.physical_path
      unless Dir.exist?(phys_path)
        raise PreservationServiceError.new("OCFL object directory does not exist or is not a directory: #{phys_path}")
      end

      # Path of the OCFL object relative to its storage location root (no leading or trailing slash)
      rel_path = file_rec.storage_location.relativize(file_rec.path)

      # Collect all local files keyed by their path relative to the object directory
      local_file_map = build_local_file_map(phys_path)

      source_loc = file_rec.storage_location
      @destinations.each do |destination|
        verify_destination_available(destination, file_rec)
        upload_files(local_file_map, rel_path, destination, file_rec)
        remove_deleted_objects(local_file_map, rel_path, destination, file_rec) if source_loc.mutable_head?
        logger.info("Replicated OCFL object #{file_rec.path} to destination #{destination.name}")
      end
    end

    # Determine if this service is applicable for the provided event
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

    # Build a map of all files under the OCFL object directory.
    #
    # @param phys_path [String] absolute path to the OCFL object directory
    # @return [Hash<String, String>] map of path-relative-to-object-dir => absolute-local-path
    def build_local_file_map(phys_path)
      obj_dir = phys_path.chomp('/')
      local_files = {}
      Find.find(phys_path) do |path|
        next if File.directory?(path)
        rel = path.sub("#{obj_dir}/", '')
        local_files[rel] = path
      end
      local_files
    end

    # Upload local files to S3, skipping any that already exist unchanged.
    def upload_files(local_file_map, rel_path, destination, file_rec)
      bucket_name = destination.s3_bucket.name
      s3_client = destination.s3_client
      transfer_manager = Aws::S3::TransferManager.new(client: s3_client)

      local_file_map.each do |rel_within_object, local_path|
        s3_key = destination.relative_to_bucket_path(File.join(rel_path, rel_within_object))

        if object_unchanged?(s3_client, bucket_name, s3_key, local_path, rel_within_object)
          logger.debug("Skipping unchanged object at #{s3_key}")
          next
        end

        begin
          transfer_manager.upload_file(local_path, bucket: bucket_name, key: s3_key)
          logger.debug("Uploaded #{local_path} to s3://#{bucket_name}/#{s3_key}")
        rescue Aws::Errors::ServiceError => e
          raise PreservationServiceError.new("Failed to transfer #{file_rec.path} (file: #{local_path}) " \
              + "to bucket '#{bucket_name}': #{e.message}")
        end
      end
    end

    # Regex matching paths relative to the OCFL object root that fall under a committed
    # version directory (e.g. `v1/`, `v2/`). All files under a version are immutable.
    VERSIONED_DIR_PATTERN = /\Av\d+\//

    # Returns true if the S3 object can be confirmed unchanged and should be skipped.
    #
    # Two strategies are used depending on the file's location within the OCFL object:
    #
    # * Files under a committed version directory (`vN/`) — Immutable so existence checks are sufficient.
    #
    # * All other files (root inventory/sidecar, namaste, mutable head inventory/sidecar,
    #   mutable head content, revision markers) — these can change over the life of an object.
    #   Mutable head content files can be superseded across commit/recreate cycles
    #   at the same revision path with different content, so existence alone is insufficient.
    #   The S3 ETag is compared to a locally computed MD5. For single-part uploads the ETag
    #   is the MD5 hex digest, so this is exact. For multipart uploads (files larger than
    #   ~15 MB, such as very large root inventories) the ETag is a composite that cannot be
    #   reproduced locally; size is used as a fallback heuristic in that case.
    def object_unchanged?(s3_client, bucket_name, s3_key, local_path, rel_within_object)
      response = s3_client.head_object(bucket: bucket_name, key: s3_key)
      if versioned_object_file?(rel_within_object)
        # All vN/ files are immutable once committed — existence is sufficient.
        true
      else
        etag = response.etag.to_s.delete('"')
        if etag.include?('-')
          # Multipart ETag — cannot verify against a local MD5; fall back to size.
          response.content_length == File.size(local_path)
        else
          etag == Digest::MD5.file(local_path).hexdigest
        end
      end
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      false
    end

    # Returns true if the path relative to the OCFL object root falls under a committed
    # version directory and is therefore immutable.
    def versioned_object_file?(rel_within_object)
      VERSIONED_DIR_PATTERN.match?(rel_within_object)
    end

    # The path prefix within an OCFL object directory for the mutable head extension.
    # Files here are removed when a mutable head is committed into a real version, making
    # this the only case in normal OCFL operation where object files are legitimately deleted.
    MUTABLE_HEAD_EXTENSION_PREFIX = 'extensions/0005-mutable-head/'

    # Delete S3 objects under the mutable head extension prefix that no longer exist locally.
    def remove_deleted_objects(local_file_map, rel_path, destination, file_rec)
      mutable_head_s3_prefix = destination.relative_to_bucket_path(
          File.join(rel_path, MUTABLE_HEAD_EXTENSION_PREFIX))
      bucket_name = destination.s3_bucket.name

      keys_to_delete = []
      # Gather all remote mutable head files as relative paths when they are not present locally
      destination.s3_bucket.objects(prefix: mutable_head_s3_prefix).each do |s3_obj|
        rel_within_object = s3_obj.key[destination.relative_to_bucket_path("#{rel_path}/").length..-1]
        keys_to_delete << s3_obj.key unless local_file_map.key?(rel_within_object)
      end

      return if keys_to_delete.empty?

      logger.debug("Removing #{keys_to_delete.size} stale S3 object(s) for #{file_rec.path}")
      keys_to_delete.each_slice(1000) do |batch|
        destination.s3_client.delete_objects(
          bucket: bucket_name,
          delete: {
            objects: batch.map { |k| { key: k } },
            quiet: true
          }
        )
      end
    rescue Aws::Errors::ServiceError => e
      raise PreservationServiceError.new("Failed to remove stale objects for #{file_rec.path} " \
          + "from bucket '#{destination.s3_bucket.name}': #{e.message}")
    end

    def verify_destination_available(destination, file_rec)
      begin
        destination.available?
      rescue StorageLocationUnavailableError => e
        raise StorageLocationUnavailableError.new("Cannot replicate #{file_rec.path} to destination " \
            + "#{destination.name}: #{e.message}")
      end
    end
  end
end
