require 'longleaf/services/storage_location_validator'
require 'longleaf/services/service_definition_validator'

FactoryBot.define do
  factory(:storage_location_validator, class: Longleaf::StorageLocationValidator) do
    initialize_with { new(config) }
  end

  factory(:service_definition_validator, class: Longleaf::ServiceDefinitionValidator) do
    initialize_with { new(config) }
  end
end
