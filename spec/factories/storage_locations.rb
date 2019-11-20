require 'longleaf/models/filesystem_storage_location'
require 'longleaf/models/filesystem_metadata_location'
require 'longleaf/services/storage_location_manager'
require 'longleaf/models/app_fields'

FactoryBot.define do
  AF ||= Longleaf::AppFields

  factory(:storage_location, class: Longleaf::FilesystemStorageLocation) do
    transient {
      path { '/file/path/' }
      metadata_path { '/metadata/path/' }
      metadata_config { { AF::LOCATION_PATH => metadata_path } }
    }

    name { 's_loc' }
    config { {
      AF::LOCATION_PATH => path
    } }
    md_loc { build(:metadata_location, config: metadata_config) }

    initialize_with { new(name, config, md_loc) }
  end

  factory(:metadata_location, class: Longleaf::FilesystemMetadataLocation) do
    transient {
      path { '/metadata/path/' }
      digests { nil }
    }

    config { {
      AF::LOCATION_PATH => path,
      AF::METADATA_DIGESTS => digests
    } }

    initialize_with { new(config) }
  end

  factory(:storage_location_manager, class: Longleaf::StorageLocationManager) do
    config { {} }

    initialize_with { new(config) }
  end
end
