require 'spec_helper'

if RUBY_ENGINE == 'jruby'
  require 'longleaf/errors'
  require 'longleaf/preservation_services/ocfl_validation_service'
  require 'longleaf/models/ocfl_storage_location'
  require 'longleaf/models/app_fields'
  require 'longleaf/specs/config_builder'
  require 'fileutils'
  require 'tmpdir'

  describe Longleaf::OcflValidationService do
    ConfigBuilder ||= Longleaf::ConfigBuilder
    OcflValidationService ||= Longleaf::OcflValidationService
    OcflStorageLocation ||= Longleaf::OcflStorageLocation
    PRESERVE_EVENT ||= Longleaf::EventNames::PRESERVE
    PreservationServiceError ||= Longleaf::PreservationServiceError
    AF ||= Longleaf::AppFields

    OCFL_FIXTURE_PATH = File.expand_path('../../fixtures/ocfl-root', __dir__) + File::SEPARATOR
    OBJECT1_REL_PATH = '141/964/af8/141964af842132b7a706ed010474c410514b472acc0d7d8f805c23e748578b8b'
    OBJECT2_REL_PATH = '51c/fdc/952/51cfdc9524d4088a1259c0c099ec2c6e9c82f69beda7920911c105e56810eeeb'

    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:ocfl_work_dir) { Dir.mktmpdir('ocfl-work') }
    # Default uses the read-only fixture directly
    let(:ocfl_root_path) { OCFL_FIXTURE_PATH }

    let(:config) {
      c = ConfigBuilder.new
        .with_services
        .with_location(name: 'ocfl_loc', path: ocfl_root_path, s_type: 'ocfl', md_path: md_dir)
        .with_mappings
        .get
      c[AF::LOCATIONS]['ocfl_loc'][OcflStorageLocation::WORK_DIR_PROPERTY] = ocfl_work_dir
      c
    }
    let(:app_manager) { build(:application_config_manager, config: config) }
    let(:storage_loc) { app_manager.location_manager.locations['ocfl_loc'] }

    after do
      FileUtils.remove_dir(md_dir)
      FileUtils.remove_dir(ocfl_work_dir)
    end

    def make_service(content_fixity_check: nil)
      properties = {}
      unless content_fixity_check.nil?
        properties[OcflValidationService::CONTENT_FIXITY_CHECK_PROPERTY] = content_fixity_check
      end
      service_def = build(:service_definition, properties: properties)
      OcflValidationService.new(service_def, app_manager)
    end

    def make_file_rec(object_rel_path)
      object_path = File.join(ocfl_root_path, object_rel_path)
      build(:file_record, file_path: object_path, storage_location: storage_loc)
    end

    describe '.initialize' do
      context 'with a service definition' do
        it { expect { make_service }.not_to raise_error }
      end
    end

    describe '.is_applicable?' do
      let(:service) { make_service }

      it 'returns true for preserve event' do
        expect(service.is_applicable?(PRESERVE_EVENT)).to be true
      end

      it 'returns false for register event' do
        expect(service.is_applicable?(Longleaf::EventNames::REGISTER)).to be false
      end

      it 'returns false for unknown event' do
        expect(service.is_applicable?('unknown')).to be false
      end
    end

    describe '.perform' do
      context 'with a valid OCFL object' do
        let(:service) { make_service }

        it 'does not raise for the first fixture object' do
          file_rec = make_file_rec(OBJECT1_REL_PATH)
          expect { service.perform(file_rec, PRESERVE_EVENT) }.not_to raise_error
        end

        it 'does not raise for the second fixture object' do
          file_rec = make_file_rec(OBJECT2_REL_PATH)
          expect { service.perform(file_rec, PRESERVE_EVENT) }.not_to raise_error
        end
      end

      context 'with content_fixity_check enabled on a valid object' do
        let(:service) { make_service(content_fixity_check: true) }

        it 'does not raise when content checksums are correct' do
          file_rec = make_file_rec(OBJECT1_REL_PATH)
          expect { service.perform(file_rec, PRESERVE_EVENT) }.not_to raise_error
        end
      end

      context 'when the storage location is not an OcflStorageLocation' do
        let(:service) { make_service }
        let(:filesystem_loc) { build(:storage_location) }

        it 'raises a PreservationServiceError' do
          file_rec = build(:file_record, file_path: '/some/path', storage_location: filesystem_loc)
          expect { service.perform(file_rec, PRESERVE_EVENT) }
            .to raise_error(PreservationServiceError, /OcflStorageLocation/)
        end
      end

      context 'when the object directory has no inventory.json' do
        let(:service) { make_service }

        it 'raises a PreservationServiceError' do
          no_inventory_dir = Dir.mktmpdir('no-inventory')
          begin
            file_rec = build(:file_record, file_path: no_inventory_dir, storage_location: storage_loc)
            expect { service.perform(file_rec, PRESERVE_EVENT) }
              .to raise_error(PreservationServiceError, /inventory\.json/)
          ensure
            FileUtils.remove_dir(no_inventory_dir)
          end
        end
      end

      context 'when the object id is not found in the repository' do
        let(:service) { make_service }

        it 'raises a PreservationServiceError' do
          fake_dir = Dir.mktmpdir('fake-ocfl-object')
          begin
            File.write(File.join(fake_dir, 'inventory.json'),
                JSON.generate('id' => 'info:fedora/does_not_exist', 'type' => 'https://ocfl.io/1.1/spec/#inventory'))
            file_rec = build(:file_record, file_path: fake_dir, storage_location: storage_loc)
            expect { service.perform(file_rec, PRESERVE_EVENT) }
              .to raise_error(PreservationServiceError, /not found in repository/)
          ensure
            FileUtils.remove_dir(fake_dir)
          end
        end
      end

      context 'when the inventory digest sidecar has been tampered with' do
        let(:corrupted_root) { Dir.mktmpdir('corrupted-ocfl') }
        let(:ocfl_root_path) { corrupted_root + File::SEPARATOR }

        before do
          FileUtils.cp_r(File.join(OCFL_FIXTURE_PATH, '.'), corrupted_root)
          sidecar = File.join(corrupted_root, OBJECT1_REL_PATH, 'inventory.json.sha512')
          File.write(sidecar, 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  inventory.json')
        end

        after do
          FileUtils.remove_dir(corrupted_root)
        end

        let(:service) { make_service }

        it 'raises a PreservationServiceError reporting the validation failure' do
          file_rec = make_file_rec(OBJECT1_REL_PATH)
          expect { service.perform(file_rec, PRESERVE_EVENT) }
            .to raise_error(PreservationServiceError, /OCFL validation failed/)
        end
      end
    end
  end
end
