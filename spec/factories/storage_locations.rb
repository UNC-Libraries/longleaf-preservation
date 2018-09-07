require 'longleaf/models/storage_location'
require 'longleaf/services/storage_location_manager'

FactoryBot.define do
  factory(:storage_location, class: Longleaf::StorageLocation) do
    name { 's_loc' }
    path { '/file/path/' }
    metadata_path { '/metadata/path/' }
    
    initialize_with { new(attributes) }
  end
  
  factory(:storage_location_manager, class: Longleaf::StorageLocationManager) do
    config { {} }

    initialize_with { new(config) }
  end
end