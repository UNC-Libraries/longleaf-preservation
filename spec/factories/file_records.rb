require 'longleaf/models/file_record'

FactoryBot.define do
  factory(:file_record, class: Longleaf::FileRecord) do
    storage_location { build(:storage_location) }
    file_path { '/metadata/path/file' }
    
    initialize_with { new(file_path, storage_location) }
  end
end