require 'spec_helper'
require 'longleaf/candidates/ocfl_file_selector'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'support/shared_examples/file_selector_examples'
require 'longleaf/errors'
require 'fileutils'

describe Longleaf::OcflFileSelector do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder

  let(:md_dir1) { make_test_dir(name: 'metadata1') }
  let(:path_dir1) { make_test_dir(name: 'path1') }
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

  let(:ocfl_object_path1) { '141/964/af8/141964af842132b7a706ed010474c410514b472acc0d7d8f805c23e748578b8b' }
  let(:ocfl_object_path2) { '51c/fdc/952/51cfdc9524d4088a1259c0c099ec2c6e9c82f69beda7920911c105e56810eeeb' }
  let!(:ocfl_path1) { File.join(path_dir1, 'ocfl-root', ocfl_object_path1) }
  let!(:ocfl_path2) { File.join(path_dir1, 'ocfl-root', ocfl_object_path2) }
  let(:expected_path1) { ocfl_path1 + '/' }
  let(:expected_path2) { ocfl_path2 + '/' }

  before do
    # Copy OCFL fixtures into path_dir, preserving timestamps
    fixtures_path = File.join(__dir__, '../../fixtures/ocfl-root')
    FileUtils.cp_r(fixtures_path, path_dir1, preserve: true)
  end

  after do
    FileUtils.rm_rf([md_dir1, md_dir2, path_dir1, path_dir2])
  end

  include_examples 'file_selector.initialize', :ocfl_file_selector
  include_examples 'file_selector.storage_locations', :ocfl_file_selector
  include_examples 'file_selector.target_paths', :ocfl_file_selector

  describe '.next_path' do
    context 'with non-existent path' do
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [File.join(path_dir1, 'nonexist')],
              app_config: app_config)
      }

      it { expect { selector.next_path }.to raise_error(Longleaf::InvalidStoragePathError, /does not exist/) }
    end

    context 'with a single OCFL object path' do
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [ocfl_path1],
              app_config: app_config)
      }

      it 'returns the OCFL object directory' do
        expect(selector.next_path).to eq expected_path1
        expect(selector.next_path).to be_nil
      end
    end

    context 'with multiple OCFL object paths' do
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [ocfl_path1, ocfl_path2],
              app_config: app_config)
      }

      it 'returns both OCFL object directories' do
        expect(selector.next_path).to eq expected_path1
        expect(selector.next_path).to eq expected_path2
        expect(selector.next_path).to be_nil
      end
    end

    context 'with parent directory containing OCFL objects' do
      let(:ocfl_root) { File.join(path_dir1, 'ocfl-root') }
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [ocfl_root],
              app_config: app_config)
      }

      it 'returns empty array since non-OCFL directories are not supported' do
        paths = collect_paths(selector)

        expect(paths).to eq []
      end
    end

    context 'with storage location containing OCFL objects' do
      let(:selector) {
        build(:ocfl_file_selector,
              storage_locations: ['loc1'],
              app_config: app_config)
      }

      it 'returns empty array since storage locations are not supported' do
        paths = collect_paths(selector)

        expect(paths).to eq []
      end
    end

    context 'with non-OCFL directory' do
      let(:non_ocfl_dir) { make_test_dir(parent: path_dir1, name: 'not_ocfl') }
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [non_ocfl_dir],
              app_config: app_config)
      }

      it 'skips the directory and returns nil' do
        expect(selector.next_path).to be_nil
      end

      it 'logs a warning about skipping' do
        expect(selector.logger).to receive(:warn).with(/Skipping.*not an OCFL object/)
        selector.next_path
      end
    end

    context 'with file instead of directory' do
      let(:file_path) { create_test_file(dir: path_dir1) }
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [file_path],
              app_config: app_config)
      }

      it 'raises an error' do
        expect { selector.next_path }.to raise_error(
          Longleaf::InvalidStoragePathError,
          /is not a directory, only directories can be provided for OCFL/
        )
      end
    end

    context 'with relative path to OCFL object' do
      let(:relative_path) { Pathname.new(ocfl_path1).relative_path_from(Pathname.new(Dir.pwd)) }
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [relative_path],
              app_config: app_config)
      }

      it 'returns the OCFL object directory' do
        expect(selector.next_path).to eq expected_path1
        expect(selector.next_path).to be_nil
      end
    end

    context 'path not in a storage location' do
      let(:path_dir3) { make_test_dir(name: 'path3') }
      let(:non_storage_dir) { make_test_dir(parent: path_dir3, name: 'outside') }
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [non_storage_dir],
              app_config: app_config)
      }

      it 'raises StorageLocationUnavailableError' do
        expect { selector.next_path }.to raise_error(Longleaf::StorageLocationUnavailableError)
      end
    end

    context 'with mixed OCFL and non-OCFL directories' do
      let(:non_ocfl_dir) { make_test_dir(parent: path_dir1, name: 'not_ocfl') }
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [ocfl_path1, non_ocfl_dir, ocfl_path2],
              app_config: app_config)
      }

      it 'returns only OCFL objects' do
        expect(selector.logger).to receive(:warn).with(/Skipping.*not an OCFL object/)
        paths = collect_paths(selector)

        expect(paths).to eq [expected_path1, expected_path2]
      end
    end
  end

  describe '.each' do
    context 'with multiple OCFL objects' do
      let(:selector) {
        build(:ocfl_file_selector,
              file_paths: [ocfl_path1, ocfl_path2],
              app_config: app_config)
      }

      it 'iterates over all OCFL objects' do
        paths = []
        selector.each do |path|
          paths << path
        end

        expect(paths).to eq [expected_path1, expected_path2]
      end
    end
  end

  def collect_paths(selector)
    paths = []
    path = selector.next_path
    until path.nil?
      paths << path
      path = selector.next_path
    end
    paths
  end
end
