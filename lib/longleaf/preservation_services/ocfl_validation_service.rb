unless RUBY_ENGINE == 'jruby'
  raise LoadError, "OcflValidationService requires JRuby — ocfl-java is not available on CRuby."
end

require 'longleaf/events/event_names'
require 'longleaf/logging'
require 'longleaf/errors'
require 'longleaf/models/ocfl_storage_location'
require 'json'

module Longleaf
  # Preservation service which validates an OCFL object using ocfl-java.
  #
  # The service is applicable to PRESERVE events and requires the storage location to be an
  # OcflStorageLocation. The OCFL object ID is read from the inventory.json in the object directory.
  #
  # Service configuration properties:
  #   * 'content_fixity_check' - Whether to verify content file checksums during validation (default: false).
  #                              Setting this to true is more thorough but significantly slower.
  class OcflValidationService
    include Longleaf::Logging

    CONTENT_FIXITY_CHECK_PROPERTY = 'content_fixity_check'

    # Initialize an OcflValidationService from the given service definition
    #
    # @param service_def [ServiceDefinition] the configuration for this service
    # @param app_manager [ApplicationConfigManager] manager for configured storage locations
    def initialize(service_def, app_manager)
      @service_def = service_def
      @app_manager = app_manager
      @content_fixity_check = service_def.properties.fetch(CONTENT_FIXITY_CHECK_PROPERTY, false)
    end

    # Perform OCFL validation of the object at the file record's physical path.
    #
    # @param file_rec [FileRecord] record representing the OCFL object directory to validate.
    # @param event [String] name of the event this service is being invoked by.
    # @raise [PreservationServiceError] if the OCFL object fails validation
    def perform(file_rec, event)
      path = file_rec.path
      phys_path = file_rec.physical_path

      storage_loc = file_rec.storage_location
      unless storage_loc.is_a?(OcflStorageLocation)
        raise PreservationServiceError.new(
            "OcflValidationService requires an OcflStorageLocation, but '#{storage_loc.name}' " \
            "is a #{storage_loc.class.name}")
      end

      ocfl_repo = storage_loc.ocfl_repository

      object_id = read_object_id(phys_path)

      if !ocfl_repo.contains_object(object_id)
        raise PreservationServiceError.new(
            "OCFL object '#{object_id}' not found in repository for path #{path}")
      end

      logger.debug("Performing OCFL validation of object '#{object_id}' at #{phys_path} " \
          "(content_fixity_check=#{@content_fixity_check})")

      results = ocfl_repo.validate_object(object_id, @content_fixity_check)

      if !results.has_errors
        logger.debug("OCFL validation succeeded for object '#{object_id}' at #{phys_path}")
      else
        issues = results.get_errors.map { |issue| issue.get_message }.join('; ')
        raise PreservationServiceError.new(
            "OCFL validation failed for object '#{object_id}' at #{path}: #{issues}")
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

    # Read the OCFL object ID from the inventory.json at the given object directory path.
    #
    # @param object_path [String] path to the OCFL object directory
    # @return [String] the OCFL object ID
    # @raise [PreservationServiceError] if the inventory cannot be read or has no id field
    def read_object_id(object_path)
      inventory_path = File.join(object_path, 'inventory.json')
      unless File.exist?(inventory_path)
        raise PreservationServiceError.new(
            "No inventory.json found at expected path: #{inventory_path}")
      end

      inventory = JSON.parse(File.read(inventory_path))
      id = inventory['id']
      if id.nil? || id.empty?
        raise PreservationServiceError.new(
            "inventory.json at #{inventory_path} does not contain a valid 'id' field")
      end
      id
    end
  end
end