require 'spec_helper'
require 'longleaf/candidates/registered_file_selector'
require 'longleaf/specs/metadata_builder'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'support/shared_examples/file_selector_examples'
require 'longleaf/errors'
require 'fileutils'

if RUBY_ENGINE == 'jruby'
  require 'longleaf/models/ocfl_storage_location'
  require 'longleaf/models/md_fields'
  require 'longleaf/models/app_fields'
end

describe Longleaf::RegisteredFileSelector do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  MetadataBuilder ||= Longleaf::MetadataBuilder

  let(:md_dir1) { make_test_dir(name: 'metadata1') }
  let!(:path_dir1) { make_test_dir(name: 'path1') }
  let(:md_dir2) { make_test_dir(name: 'metadata2') }
  let(:path_dir2) { make_test_dir(name: 'path2') }

  let(:config) {
    ConfigBuilder.new
      .with_services
      .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
      .with_location(name: 'loc2', path: path_dir2, md_path: md_dir2)
      .with_mappings
      .get
  }
  let(:app_config) { build(:application_config_manager, config: config) }

  after do
    FileUtils.rm_rf([md_dir1, md_dir2, path_dir1, path_dir2])
  end

  include_examples 'file_selector.initialize', :registered_file_selector
  include_examples 'file_selector.storage_locations', :registered_file_selector
  include_examples 'file_selector.target_paths', :registered_file_selector

  describe '.next_path' do
    context 'with non-existent file path' do
      let(:selector) {
        build(:registered_file_selector,
              file_paths: [File.join(path_dir1, 'nonexist')],
              app_config: app_config)
      }

      it { expect { selector.next_path }.to raise_error(Longleaf::InvalidStoragePathError) }
    end

    context 'with a registered file path' do
      let(:file_path) { create_registered_file(path_dir1) }
      let(:selector) {
        build(:registered_file_selector,
              file_paths: [file_path],
              app_config: app_config)
      }

      it 'returns one path' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end

    context 'with an unregistered file path' do
      let(:file_path) { create_test_file(dir: path_dir1) }
      let(:selector) {
        build(:registered_file_selector,
              file_paths: [file_path],
              app_config: app_config)
      }

      it { expect { selector.next_path }.to raise_error(Longleaf::RegistrationError) }
    end

    context 'with multiple registered file path' do
      let!(:file_path1) { create_registered_file(path_dir1, 'file1') }
      let!(:file_path2) { create_registered_file(path_dir1, 'file2') }

      context 'selecting by paths' do
        let(:selector) {
          build(:registered_file_selector,
                file_paths: [file_path1, file_path2],
                app_config: app_config)
        }

        it 'returns two paths' do
          expect(selector.next_path).to eq file_path1
          expect(selector.next_path).to eq file_path2
          expect(selector.next_path).to be_nil
        end
      end

      context 'selecting by storage location' do
        let(:selector) {
          build(:registered_file_selector,
                storage_locations: ['loc1'],
                app_config: app_config)
        }

        it 'returns two paths' do
          expect(selector.next_path).to eq file_path1
          expect(selector.next_path).to eq file_path2
          expect(selector.next_path).to be_nil
        end
      end
    end

    context 'with directory containing registered file' do
      let(:dir_path) { make_test_dir(parent: path_dir1, name: 'nested') }
      let!(:file_path) { create_registered_file(dir_path) }
      let(:selector) {
        build(:registered_file_selector,
              file_paths: [dir_path],
              app_config: app_config)
      }

      it 'returns contained file' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end

    context 'multiple storage locations' do
      let!(:file_path1) { create_registered_file(path_dir1) }
      let!(:file_path2) { create_registered_file(path_dir2) }
      let(:selector) {
        build(:registered_file_selector,
              storage_locations: ['loc1', 'loc2'],
              app_config: app_config)
      }

      it 'returns contained file from each location' do
        expect(selector.next_path).to eq file_path1
        expect(selector.next_path).to eq file_path2
        expect(selector.next_path).to be_nil
      end
    end

    context 'empty storage location' do
      let(:selector) {
        build(:registered_file_selector,
              storage_locations: ['loc1'],
              app_config: app_config)
      }

      it 'returns contained file' do
        expect(selector.next_path).to be_nil
      end
    end

    context 'path not in a storage location' do
      let(:path_dir3) { make_test_dir(name: 'path3') }
      let!(:file_path1) { create_test_file(dir: path_dir3) }
      let(:selector) {
        build(:registered_file_selector,
              file_paths: [file_path1],
              app_config: app_config)
      }

      it 'raises StorageLocationUnavailableError and skips file' do
        expect { selector.next_path }.to raise_error(Longleaf::StorageLocationUnavailableError)
      end
    end

    if RUBY_ENGINE == 'jruby'
      OcflStorageLocation ||= Longleaf::OcflStorageLocation
      MDFields ||= Longleaf::MDFields
      AF ||= Longleaf::AppFields

      context 'with OCFL storage location' do
        let(:ocfl_root) { Dir.mktmpdir('ocfl-root') }
        let(:ocfl_md_dir) { Dir.mktmpdir('ocfl-metadata') }
        let(:ocfl_work_dir) { Dir.mktmpdir('ocfl-work') }

        let(:ocfl_config) {
          c = ConfigBuilder.new
            .with_services
            .with_location(name: 'ocfl_loc', path: ocfl_root, s_type: 'ocfl', md_path: ocfl_md_dir)
            .with_mappings
            .get
          c[AF::LOCATIONS]['ocfl_loc'][OcflStorageLocation::WORK_DIR_PROPERTY] = ocfl_work_dir
          c
        }
        let(:ocfl_app_config) { build(:application_config_manager, config: ocfl_config) }

        after do
          FileUtils.rm_rf([ocfl_root, ocfl_md_dir, ocfl_work_dir])
        end

        context 'with a registered OCFL object path' do
          let(:object_path) { create_registered_ocfl_object(ocfl_root, ocfl_app_config) }
          let(:selector) {
            build(:registered_file_selector,
                  file_paths: [object_path],
                  app_config: ocfl_app_config)
          }

          it 'returns the OCFL object path with trailing slash' do
            expect(selector.next_path).to eq object_path
            expect(selector.next_path).to be_nil
          end
        end

        context 'with an unregistered OCFL object (directory exists, no metadata)' do
          let(:object_path) {
            path = File.join(ocfl_root, 'unregistered_obj') + '/'
            FileUtils.mkdir_p(path)
            path
          }
          let(:selector) {
            build(:registered_file_selector,
                  file_paths: [object_path],
                  app_config: ocfl_app_config)
          }

          it 'raises RegistrationError' do
            expect { selector.next_path }.to raise_error(Longleaf::RegistrationError)
          end
        end

        context 'with multiple registered OCFL objects selected by storage location' do
          let!(:object_path1) { create_registered_ocfl_object(ocfl_root, ocfl_app_config, 'obj1') }
          let!(:object_path2) { create_registered_ocfl_object(ocfl_root, ocfl_app_config, 'obj2') }
          let(:selector) {
            build(:registered_file_selector,
                  storage_locations: ['ocfl_loc'],
                  app_config: ocfl_app_config)
          }

          it 'returns all registered OCFL objects' do
            results = []
            while (path = selector.next_path)
              results << path
            end
            expect(results).to contain_exactly(object_path1, object_path2)
          end
        end
      end
    end
  end

  def create_registered_file(path_dir, file_prefix = nil)
    file_path = create_test_file(dir: path_dir, name: file_prefix)
    storage_loc = app_config.location_manager.get_location_by_path(file_path)
    file_rec = build(:file_record, storage_location: storage_loc, file_path: file_path)
    MetadataBuilder.new(file_path: file_path)
        .write_to_yaml_file(file_rec: file_rec)
    file_path
  end

  if RUBY_ENGINE == 'jruby'
    def create_registered_ocfl_object(ocfl_root, ocfl_app_config, obj_name = 'test_obj')
      object_path = File.join(ocfl_root, obj_name) + '/'
      FileUtils.mkdir_p(object_path)
      storage_loc = ocfl_app_config.location_manager.get_location_by_path(object_path)
      file_rec = Longleaf::FileRecord.new(object_path, storage_loc, nil, nil,
                                          object_type: Longleaf::MDFields::OCFL_TYPE)
      MetadataBuilder.new.write_to_yaml_file(file_rec: file_rec)
      object_path
    end
  end
end
