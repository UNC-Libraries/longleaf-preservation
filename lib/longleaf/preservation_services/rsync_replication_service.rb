require 'longleaf/events/event_names'
require 'longleaf/logging'
require 'longleaf/errors'
require 'longleaf/models/file_record'
require 'longleaf/models/service_fields'
require 'longleaf/events/register_event'
require 'longleaf/candidates/single_digest_provider'
require 'open3'

module Longleaf
  # Preservation service which performs replication of a file to one or more destinations using rsync.
  #
  # The service definition must contain one or more destinations, specified with the "to" property.
  # These destinations must be either a known storage location name, a remote path, or absolute path.
  #
  # Optional service configuration properties:
  # * replica_collision_policy = specifies the desired outcome if the service attempts to replicate
  #     a file which already exists at a destination. Default: "replace".
  # * rsync_command = the command to invoke in order to execute rsync. Default: "rsync"
  # * rsync_options = additional parameters that will be passed along to rsync. Cannot include options
  #     which change the target of the command or prevent its execution, such as "files-from", "dry-run",
  #     "help", etc. Command will always include "-R". Default "-a".
  class RsyncReplicationService
    include Longleaf::Logging
    SF ||= Longleaf::ServiceFields

    RSYNC_COMMAND_PROPERTY = "rsync_command"
    DEFAULT_COMMAND = "rsync"

    RSYNC_OPTIONS_PROPERTY = "rsync_options"
    DEFAULT_OPTIONS = "-a"
    DISALLOWED_OPTIONS = ["files-from", "n", "dry-run", "exclude", "exclude-from", "cvs-exclude",
       "h", "help", "f", "F", "filter"]

    attr_reader :command, :options, :collision_policy

    # Initialize a RsyncReplicationService from the given service definition
    #
    # @param service_def [ServiceDefinition] the configuration for this service
    # @param app_manager [ApplicationConfigManager] the application configuration
    def initialize(service_def, app_manager)
      @service_def = service_def
      @app_manager = app_manager

      @command = @service_def.properties[RSYNC_COMMAND_PROPERTY] || DEFAULT_COMMAND

      # Validate rsync parameters
      @options = @service_def.properties[RSYNC_OPTIONS_PROPERTY] || DEFAULT_OPTIONS
      if contains_disallowed_option?(@options)
        raise ArgumentError.new("Service #{service_def.name} specifies a disallowed rsync paramter," \
            + " rsync_options may not include the following: #{DISALLOWED_OPTIONS.join(' ')}")
      end

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
        # Assume that if destination contains a : or / it is a path rather than storage location
        if dest =~ /[:\/]/
          @destinations << dest
        else
          if loc_manager.locations.key?(dest)
            @destinations << loc_manager.locations[dest]
          else
            raise ArgumentError.new("Service #{service_def.name} specifies unknown storage location '#{dest}'" \
                + " as a replication destination")
          end
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
      @destinations.each do |destination|
        dest_is_storage_loc = destination.is_a?(Longleaf::StorageLocation)

        if dest_is_storage_loc
          dest_path = destination.path
        else
          dest_path = destination
        end
        
        logical_physical_same = file_rec.path == file_rec.physical_path
        # Determine the path to the file being replicated relative to its storage location
        rel_path = file_rec.storage_location.relativize(file_rec.path)
        
        options = @options
        if logical_physical_same
          options = options + " -R"
          # source path with . so that rsync will only create destination directories starting from that point
          source_path = File.join(file_rec.storage_location.path, "./#{rel_path}")
        else
          options = options + " --no-relative"
          source_path = file_rec.physical_path
          dest_path = File.join(dest_path, rel_path)
          if (dest_is_storage_loc && destination.is_a?(Longleaf::FilesystemStorageLocation)) || !dest_is_storage_loc
            # Fill in missing parent directories, as rsync cannot do so when specifying a different source and dest filename
            dirname = File.dirname(dest_path)
            logger.debug("Creating parent dirs #{dirname} for #{file_rec.path}")
            FileUtils.mkdir_p(dirname)
          else
            raise PreservationServiceError.new(
                "Destination #{destination.name} does not currently support separate physical and logical paths")
          end
        end

        # Check that the destination is available because attempting to write
        verify_destination_available(destination, file_rec)

        logger.debug("Invoking rsync with command: #{@command} \"#{source_path}\" \"#{dest_path}\" #{options}")
        stdout, stderr, status = Open3.capture3("#{@command} \"#{source_path}\" \"#{dest_path}\" #{options}")
        raise PreservationServiceError.new("Failed to replicate #{file_rec.path} to #{dest_path}: #{stderr}") \
            unless status.success?

        logger.info("Replicated #{file_rec.path} to destination #{dest_path}")

        # For destinations which are storage locations, register the replica with longleaf
        if dest_is_storage_loc
          register_replica(destination, rel_path, file_rec)
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

    private
    def contains_disallowed_option?(options)
      DISALLOWED_OPTIONS.each do |disallowed|
        if disallowed.length == 1
          if options =~ /(\A| )-[a-zA-Z0-9]*#{disallowed}[a-zA-Z0-9]*( |=|\z)/
            return true
          end
        else
          if options =~ /(\A| )--#{disallowed}( |=|\z)/
            return true
          end
        end
      end

      false
    end

    def verify_destination_available(destination, file_rec)
      if destination.is_a?(Longleaf::StorageLocation)
        begin
          destination.available?
        rescue StorageLocationUnavailableError => e
          raise StorageLocationUnavailableError.new("Cannot replicate #{file_rec.path} to destination #{destination.name}: " \
              + e.message)
        end
      elsif destination.start_with?("/")
        raise StorageLocationUnavailableError.new("Cannot replicate #{file_rec.path} to destination" \
            + " #{destination}, path does not exist.") unless Dir.exist?(destination)
      end
    end

    def register_replica(destination, rel_path, file_rec)
      dest_file_path = File.join(destination.path, rel_path)
      dest_file_rec = FileRecord.new(dest_file_path, destination)

      register_event = RegisterEvent.new(file_rec: dest_file_rec,
          app_manager: @app_manager,
          force: true,
          digest_provider: SingleDigestProvider.new(file_rec.metadata_record.checksums))
      register_event.perform
    end
  end
end
