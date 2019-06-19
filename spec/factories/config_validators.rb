require 'longleaf/services/application_config_validator'
require 'longleaf/services/service_definition_validator'
require 'longleaf/services/service_mapping_validator'
require 'longleaf/services/storage_location_validator'

FactoryBot.define do
  factory(:application_config_validator, class: Longleaf::ApplicationConfigValidator) do
    initialize_with { new(config) }
  end

  factory(:storage_location_validator, class: Longleaf::StorageLocationValidator) do
    initialize_with { new(config) }
  end

  factory(:service_definition_validator, class: Longleaf::ServiceDefinitionValidator) do
    initialize_with { new(config) }
  end

  factory(:service_mapping_validator, class: Longleaf::ServiceMappingValidator) do
    initialize_with { new(config) }
  end
end
