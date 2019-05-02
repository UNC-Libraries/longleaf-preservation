require 'spec_helper'
require 'longleaf/candidates/file_selector'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'longleaf/errors'
require 'fileutils'

describe Longleaf::FileSelector do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  let(:md_dir1) { make_test_dir(name: 'metadata1') }
  let(:path_dir1) { make_test_dir(name: 'path1') }
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
  
  describe '.initialize' do
    context 'no file paths or storage locations' do
      it { expect{ build(:file_selector, file_paths: nil, storage_locations: nil, app_config: app_config) }.to \
          raise_error(ArgumentError) }
    end
    
    context 'with empty file paths' do
      it { expect{ build(:file_selector, file_paths: [], storage_locations: nil, app_config: app_config) }.to \
          raise_error(ArgumentError) }
    end
    
    context 'both file paths and storage locations' do
      it { expect{ build(:file_selector, 
        file_paths: [File.join(path_dir1, 'file')],
        storage_locations: ['loc1'],
        app_config: app_config) }.to raise_error(ArgumentError) }
    end
    
    context 'invalid storage location name' do
      it { expect{ build(:file_selector,
        storage_locations: ['foo'],
        app_config: app_config) }.to raise_error(Longleaf::StorageLocationUnavailableError) }
    end
    
    context 'valid storage location' do
      it { expect(build(:file_selector, 
        storage_locations: ['loc1'],
        app_config: app_config)).to be_a Longleaf::FileSelector }
    end
    
    context 'valid file path' do
      it { expect(build(:file_selector, 
        file_paths: [File.join(path_dir1, 'file')],
        app_config: app_config)).to be_a Longleaf::FileSelector }
    end
  end
  
  describe '.next_path' do
    context 'with non-existent file path' do
      let(:selector) { build(:file_selector, 
              file_paths: [File.join(path_dir1, 'nonexist')],
              app_config: app_config) }
      
      it { expect{ selector.next_path }.to raise_error(Longleaf::InvalidStoragePathError) }
    end
    
    context 'with a file path' do
      let(:file_path) { create_test_file(dir: path_dir1) }
      let(:selector) { build(:file_selector, 
              file_paths: [file_path],
              app_config: app_config) }
      
      it 'returns one path' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'with multiple file path' do
      let(:file_path1) { Tempfile.new('file1', path_dir1).path }
      let(:file_path2) { Tempfile.new('file2', path_dir1).path }
      let(:selector) { build(:file_selector, 
              file_paths: [file_path1, file_path2],
              app_config: app_config) }
      
      it 'returns two paths' do
        expect(selector.next_path).to eq file_path1
        expect(selector.next_path).to eq file_path2
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'with directory containing file' do
      let(:dir_path) { make_test_dir(parent: path_dir1, name: 'nested') }
      let!(:file_path) { create_test_file(dir: dir_path) }
      let(:selector) { build(:file_selector, 
              file_paths: [dir_path],
              app_config: app_config) }
      
      it 'returns contained file' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'storage location contain file' do
      let!(:file_path) { create_test_file(dir: path_dir1) }
      
      let(:selector) { build(:file_selector, 
              storage_locations: ['loc1'],
              app_config: app_config) }
      
      it 'returns contained file' do
        expect(selector.next_path).to eq file_path
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'multiple storage locations' do
      let!(:file_path1) { create_test_file(dir: path_dir1) }
      let!(:file_path2) { create_test_file(dir: path_dir2) }
      let(:selector) { build(:file_selector, 
              storage_locations: ['loc1', 'loc2'],
              app_config: app_config) }
      
      it 'returns contained file from each location' do
        expect(selector.next_path).to eq file_path1
        expect(selector.next_path).to eq file_path2
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'empty storage location' do
      let(:selector) { build(:file_selector, 
              storage_locations: ['loc1'],
              app_config: app_config) }
      
      it 'returns contained file' do
        expect(selector.next_path).to be_nil
      end
    end
    
    context 'path not in a storage location' do
      let(:path_dir3) { make_test_dir(name: 'path3') }
      let!(:file_path1) { create_test_file(dir: path_dir3) }
      let(:selector) { build(:file_selector, 
              file_paths: [file_path1],
              app_config: app_config) }
      
      it 'raises StorageLocationUnavailableError and skips file' do
        expect { selector.next_path }.to raise_error(Longleaf::StorageLocationUnavailableError)
        expect(selector.next_path).to be_nil
      end
    end
  end
  
  describe '.storage_locations' do
    context 'with valid storage locations' do
      let(:selector) { build(:file_selector, 
              storage_locations: ['loc1', 'loc2'],
              app_config: app_config) }
      it { expect(selector.storage_locations).to contain_exactly('loc1', 'loc2')}
    end
    
    context 'with one file path' do
      let(:selector) { build(:file_selector, 
              file_paths: [File.join(path_dir1, 'file')],
              app_config: app_config) }
      it { expect(selector.storage_locations).to contain_exactly('loc1')}
    end
    
    context 'with multiple file paths' do
      let(:selector) { build(:file_selector, 
              file_paths: [File.join(path_dir1, 'file1'), File.join(path_dir1, 'file2')],
              app_config: app_config) }
      it { expect(selector.storage_locations).to contain_exactly('loc1')}
    end
    
    context 'with file paths in multiple locations' do
      let(:selector) { build(:file_selector, 
              file_paths: [File.join(path_dir1, 'file1'), File.join(path_dir2, 'other')],
              app_config: app_config) }
      it { expect(selector.storage_locations).to contain_exactly('loc1', 'loc2')}
    end
    
    context 'with file paths not in storage location' do
      let(:path_dir3) { make_test_dir() }
      after do
        FileUtils.rmdir([path_dir3])
      end
      
      let(:selector) { build(:file_selector, 
              file_paths: [File.join(path_dir3, 'file')],
              app_config: app_config) } 
      it { expect(selector.storage_locations).to contain_exactly()}
    end
  end
  
  describe '.target_paths' do
    context 'from file paths' do
      let(:dir_path) { make_test_dir(parent: path_dir1, name: 'nested') }
      let(:selector) { build(:file_selector, 
              file_paths: [dir_path],
              app_config: app_config) }
      
      it 'returns storage location path' do
        expect(selector.target_paths).to contain_exactly(dir_path + '/')
      end
    end
    
    context 'from storage location' do
      let(:selector) { build(:file_selector, 
              storage_locations: ['loc1'],
              app_config: app_config) }
      
      it 'returns storage location path' do
        expect(selector.target_paths).to contain_exactly(path_dir1 + '/')
      end
    end
  end
end