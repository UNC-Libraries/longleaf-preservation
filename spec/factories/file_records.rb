require 'longleaf/models/file_record'

FactoryBot.define do
  factory(:file_record, class: Longleaf::FileRecord) do
    storage_location { build(:storage_location) }
    file_path { '/file/path/file' }
    metadata_record { nil }
    physical_path { nil }

    initialize_with { new(file_path, storage_location, metadata_record, physical_path) }
  end
end
