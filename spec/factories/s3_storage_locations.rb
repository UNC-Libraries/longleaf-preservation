require 'longleaf/models/s3_storage_location'
require 'longleaf/models/filesystem_metadata_location'
require 'longleaf/models/app_fields'

FactoryBot.define do
  AF ||= Longleaf::AppFields

  factory(:s3_storage_location, class: Longleaf::S3StorageLocation) do
    transient {
      path { 'https://example.s3-amazonaws.com/path/' }
      metadata_path { '/metadata/path/' }
      metadata_config { { AF::LOCATION_PATH => metadata_path } }
      options { { 'stub_responses' => true } }
    }

    name { 's_loc' }
    config { {
      AF::LOCATION_PATH => path,
      'options' => options
    } }
    md_loc { build(:metadata_location, config: metadata_config) }

    initialize_with { new(name, config, md_loc) }
  end
end
