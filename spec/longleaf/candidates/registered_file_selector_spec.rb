require 'spec_helper'
require 'longleaf/candidates/registered_file_selector'
require 'longleaf/specs/metadata_builder'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'support/shared_examples/file_selector_examples'
require 'longleaf/errors'
require 'fileutils'


describe Longleaf::RegisteredFileSelector do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  MetadataBuilder ||= Longleaf::MetadataBuilder
  
  let(:md_dir1) { make_test_dir(name: 'metadata1') }
  let!(:path_dir1) { make_test_dir(name: 'path1') }
  let(:md_dir2) { make_test_dir(name: 'metadata2') }
  let(:path_dir2) { make_test_dir(name: 'path2') }
  
  let(:config) { ConfigBuilder.new
      .with_services
      .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
      .with_location(name: 'loc2', path: path_dir2, md_path: md_dir2)
      .with_mappings
      .get }
  let(:app_config) { build(:application_config_manager, config: config) }
  
  after do
    FileUtils.rm_rf([md_dir1, md_dir2, path_dir1, path_dir2])
  end

  include_examples 'file_selector.initialize', :registered_file_selector
  include_examples 'file_selector.storage_locations', :registered_file_selector
  include_examples 'file_selector.target_paths', :registered_file_selector
  
  describe '.next_path' do
    context 'with non-existent file path' do
      let(:selector) { build(:registered_file_selector, 
              file_paths: [File.join(path_dir1, 'nonexist')],
              app_config: app_config) }
      
      it { expect{ selector.next_path }.to raise_error(Longleaf::InvalidStoragePathError) }
    end
    
    context 'with a registered file path' do
      let(:file_path) { create_registered_file(path_dir1) }
      let(:selector) { build(:registered_file_selector, 
              file_paths: [file_path],
              app_config: app_config) }
      
      it 'returns one path' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'with an unregistered file path' do
      let(:file_path) { create_test_file(dir: path_dir1) }
      let(:selector) { build(:registered_file_selector, 
              file_paths: [file_path],
              app_config: app_config) }
      
      it { expect { selector.next_path }.to raise_error(Longleaf::RegistrationError) }
    end
    
    context 'with multiple registered file path' do
      let!(:file_path1) { create_registered_file(path_dir1, 'file1') }
      let!(:file_path2) { create_registered_file(path_dir1, 'file2') }
      
      context 'selecting by paths' do
        let(:selector) { build(:registered_file_selector, 
                file_paths: [file_path1, file_path2],
                app_config: app_config) }
                
        it 'returns two paths' do
          expect(selector.next_path).to eq file_path1
          expect(selector.next_path).to eq file_path2
          expect(selector.next_path).to be_nil
        end
      end
      
      context 'selecting by storage location' do
        let(:selector) { build(:registered_file_selector, 
                storage_locations: ['loc1'],
                app_config: app_config) }
                
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
      let(:selector) { build(:registered_file_selector, 
              file_paths: [dir_path],
              app_config: app_config) }
      
      it 'returns contained file' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'multiple storage locations' do
      let!(:file_path1) { create_registered_file(path_dir1) }
      let!(:file_path2) { create_registered_file(path_dir2) }
      let(:selector) { build(:registered_file_selector, 
              storage_locations: ['loc1', 'loc2'],
              app_config: app_config) }
      
      it 'returns contained file from each location' do
        expect(selector.next_path).to eq file_path1
        expect(selector.next_path).to eq file_path2
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'empty storage location' do
      let(:selector) { build(:registered_file_selector, 
              storage_locations: ['loc1'],
              app_config: app_config) }
      
      it 'returns contained file' do
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'path not in a storage location' do
      let(:path_dir3) { make_test_dir(name: 'path3') }
      let!(:file_path1) { create_test_file(dir: path_dir3) }
      let(:selector) { build(:registered_file_selector, 
              file_paths: [file_path1],
              app_config: app_config) }
      
      it 'raises StorageLocationUnavailableError and skips file' do
        expect { selector.next_path }.to raise_error(Longleaf::StorageLocationUnavailableError)
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
end