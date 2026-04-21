if RUBY_ENGINE == 'jruby'
  require 'longleaf/models/ocfl_storage_location'
  require 'longleaf/models/filesystem_metadata_location'
  require 'longleaf/models/app_fields'

  FactoryBot.define do
    AF ||= Longleaf::AppFields

    factory(:ocfl_storage_location, class: Longleaf::OcflStorageLocation) do
      transient {
        path { File.expand_path('../../fixtures/ocfl-root', __dir__) + File::SEPARATOR }
        metadata_path { '/metadata/path/' }
        metadata_config { { AF::LOCATION_PATH => metadata_path } }
        digest_algorithm { nil }
        verify_inventory { nil }
      }

      name { 'ocfl_loc' }
      config {
        c = { AF::LOCATION_PATH => path }
        unless digest_algorithm.nil?
          c[Longleaf::OcflStorageLocation::DIGEST_ALGORITHM_PROPERTY] = digest_algorithm
        end
        unless verify_inventory.nil?
          c[Longleaf::OcflStorageLocation::VERIFY_INVENTORY_PROPERTY] = verify_inventory
        end
        c
      }
      md_loc { build(:metadata_location, config: metadata_config) }

      initialize_with { new(name, config, md_loc) }
    end
  end
end
