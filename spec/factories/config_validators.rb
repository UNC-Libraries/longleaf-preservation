require 'longleaf/services/storage_location_validator'

FactoryBot.define do
  factory(:storage_location_validator, class: Longleaf::StorageLocationValidator) do
    initialize_with { new(config) }
  end
end
