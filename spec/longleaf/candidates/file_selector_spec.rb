require 'spec_helper'
require 'longleaf/candidates/file_selector'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'support/shared_examples/file_selector_examples'
require 'longleaf/errors'
require 'fileutils'

describe Longleaf::FileSelector do
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

  after do
    FileUtils.rm_rf([md_dir1, md_dir2, path_dir1, path_dir2])
  end

  include_examples 'file_selector.initialize', :registered_file_selector
  include_examples 'file_selector.storage_locations', :registered_file_selector
  include_examples 'file_selector.target_paths', :registered_file_selector

  describe '.next_path' do
    context 'with non-existent file path' do
      let(:selector) {
        build(:file_selector,
              file_paths: [File.join(path_dir1, 'nonexist')],
              app_config: app_config)
      }

      it { expect { selector.next_path }.to raise_error(Longleaf::InvalidStoragePathError) }
    end

    context 'with a file path' do
      let(:file_path) { create_test_file(dir: path_dir1) }
      let(:selector) {
        build(:file_selector,
              file_paths: [file_path],
              app_config: app_config)
      }

      it 'returns one path' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end

    context 'with a relative file path' do
      let(:file_path) { create_test_file(dir: path_dir1) }
      # Producing a relative path from the current working dir to where the file is actually
      let(:relative_path) { Pathname.new(file_path).relative_path_from(Pathname.new(Dir.pwd)) }
      let(:selector) {
        build(:file_selector,
              file_paths: [relative_path],
              app_config: app_config)
      }

      it 'returns one path' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end

    context 'with multiple file path' do
      let(:file_path1) { Tempfile.new('file1', path_dir1).path }
      let(:file_path2) { Tempfile.new('file2', path_dir1).path }
      let(:selector) {
        build(:file_selector,
              file_paths: [file_path1, file_path2],
              app_config: app_config)
      }

      it 'returns two paths' do
        expect(selector.next_path).to eq file_path1
        expect(selector.next_path).to eq file_path2
        expect(selector.next_path).to be_nil
      end
    end

    context 'with directory containing file' do
      let(:dir_path) { make_test_dir(parent: path_dir1, name: 'nested') }
      let!(:file_path) { create_test_file(dir: dir_path) }
      let(:selector) {
        build(:file_selector,
              file_paths: [dir_path],
              app_config: app_config)
      }

      it 'returns contained file' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end

    context 'storage location contain file' do
      let!(:file_path) { create_test_file(dir: path_dir1) }

      let(:selector) {
        build(:file_selector,
              storage_locations: ['loc1'],
              app_config: app_config)
      }

      it 'returns contained file' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end

    context 'multiple storage locations' do
      let!(:file_path1) { create_test_file(dir: path_dir1) }
      let!(:file_path2) { create_test_file(dir: path_dir2) }
      let(:selector) {
        build(:file_selector,
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
        build(:file_selector,
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
        build(:file_selector,
              file_paths: [file_path1],
              app_config: app_config)
      }

      it 'raises StorageLocationUnavailableError and skips file' do
        expect { selector.next_path }.to raise_error(Longleaf::StorageLocationUnavailableError)
        expect(selector.next_path).to be_nil
      end
    end
  end
end
