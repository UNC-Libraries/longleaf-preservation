require 'spec_helper'
require 'tmpdir'
require 'longleaf/models/storage_location'
require 'longleaf/errors'
require 'fileutils'

describe Longleaf::StorageLocation do

  describe '.initialize' do
    context 'with no metadata_path' do
      it { expect { build(:storage_location, metadata_path: nil) }.to raise_error(ArgumentError) }
    end
    context 'with no path' do
      it { expect { build(:storage_location, path: nil) }.to raise_error(ArgumentError) }
    end
    context 'with no name' do
      it { expect { build(:storage_location, name: nil) }.to raise_error(ArgumentError) }
    end
  end

  describe '.path' do
    let(:location) { build(:storage_location) }
    
    it { expect(location.path).to eq '/file/path/' }
  end
  
  describe '.metadata_path' do
    let(:location) { build(:storage_location) }
    
    it { expect(location.metadata_path).to eq '/metadata/path/' }
  end

  describe '.get_metadata_path_for' do
    let(:location) { build(:storage_location) }
    
    context 'no file_path' do
      it { expect { location.get_metadata_path_for }.to raise_error(ArgumentError) }
    end
    
    context 'nil file_path' do
      it { expect { location.get_metadata_path_for(nil) }.to raise_error(ArgumentError) }
    end
    
    context 'empty file_path' do
      it { expect { location.get_metadata_path_for('') }.to raise_error(ArgumentError) }
    end
    
    context 'path not in storage location' do
      it { expect { location.get_metadata_path_for('/some/other/path/file') }.to raise_error(ArgumentError,
          /Provided file path is not contained by storage location/) }
    end
    
    context 'valid path' do
      it { expect(location.get_metadata_path_for('/file/path/sub/myfile.txt')).to eq '/metadata/path/sub/myfile.txt'}
    end
    
    context 'path containing repeated path' do
      it { expect(location.get_metadata_path_for('/file/path/file/path/myfile.txt')).to eq '/metadata/path/file/path/myfile.txt'}
    end
  end
  
  describe '. validator' do
    context 'with non-existent path' do
      # Ensuring that the directory does not exist
      let(:path_dir) { FileUtils.rmdir(Dir.mktmpdir('path'))[0] }
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:location) { build(:storage_location, path: path_dir, metadata_path: md_dir) }
      
      after(:each) do
        FileUtils.rmdir(md_dir)
      end
      
      it { expect { location. validator }.to raise_error(Longleaf::StorageLocationUnavailableError, /Path does not exist/) }
    end
    
    context 'with non-directory path' do
      let(:file_path) { Tempfile.new('file_as_path')}
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:location) { build(:storage_location, path: file_path, metadata_path: md_dir) }
      
      after(:each) do
        file_path.unlink
        FileUtils.rmdir(md_dir)
      end
      
      it { expect { location. validator }.to raise_error(Longleaf::StorageLocationUnavailableError,\
          /Path does not exist or is not a directory/) }
    end
    
    context 'with non-existent metadata path' do
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:md_dir) { FileUtils.rmdir(Dir.mktmpdir('metadata'))[0] }
      let(:location) { build(:storage_location, path: path_dir, metadata_path: md_dir) }
      
      after(:each) do
        FileUtils.rmdir(path_dir)
      end
      
      it { expect { location. validator }.to raise_error(Longleaf::StorageLocationUnavailableError,\
          /Metadata path does not exist/) }
    end
    
    context 'with valid paths' do
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:location) { build(:storage_location, path: path_dir, metadata_path: md_dir) }
      
      after(:each) do
        FileUtils.rmdir([path_dir, md_dir])
      end
      
      it { expect { location. validator }.to_not raise_error }
    end
  end
end