require 'spec_helper'
require 'longleaf/models/storage_location'

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
end