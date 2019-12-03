require 'spec_helper'
require 'tmpdir'
require 'longleaf/models/filesystem_storage_location'
require 'longleaf/models/metadata_location'
require 'longleaf/errors'
require 'fileutils'
require 'tempfile'

describe Longleaf::FilesystemStorageLocation do
  describe '.initialize' do
    context 'with no config' do
      it { expect { build(:storage_location, config: nil) }.to raise_error(ArgumentError) }
    end
    context 'with no metadata location' do
      it { expect { build(:storage_location, md_loc: nil) }.to raise_error(ArgumentError) }
    end
    context 'with no name' do
      it { expect { build(:storage_location, name: nil) }.to raise_error(ArgumentError) }
    end
  end

  describe '.path' do
    let(:location) { build(:storage_location) }

    it { expect(location.path).to eq '/file/path/' }
  end

  describe '.metadata_location' do
    let(:location) { build(:storage_location) }

    it { expect(location.metadata_location).to be_a(Longleaf::MetadataLocation) }
  end

  describe '.get_metadata_path_for' do
    let(:md_loc) { build(:metadata_location) }
    let(:location) { build(:storage_location, md_loc: md_loc) }

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
      it {
        expect { location.get_metadata_path_for('/some/other/path/file') }.to raise_error(ArgumentError,
          /Provided file path is not contained by storage location/)
      }
    end

    context 'valid path' do
      it {
        expect(location.get_metadata_path_for('/file/path/sub/myfile.txt'))
          .to eq '/metadata/path/sub/myfile.txt-llmd.yaml'
      }
    end

    context 'path containing repeated path' do
      it {
        expect(location.get_metadata_path_for('/file/path/file/path/myfile.txt'))
          .to eq '/metadata/path/file/path/myfile.txt-llmd.yaml'
      }
    end

    context 'metadata location without trailing slash' do
      let(:location) { build(:storage_location, metadata_path: '/metadata/path') }

      it {
        expect(location.get_metadata_path_for('/file/path/sub/myfile.txt'))
          .to eq '/metadata/path/sub/myfile.txt-llmd.yaml'
      }
    end

    context 'directory file_path' do
      it {
        expect(location.get_metadata_path_for('/file/path/file/path/subdir/'))
          .to eq '/metadata/path/file/path/subdir/'
      }
    end
  end

  describe '.get_path_from_metadata_path' do
    let(:location) { build(:storage_location) }

    context 'nil file_path' do
      it { expect { location.get_path_from_metadata_path(nil) }.to raise_error(ArgumentError) }
    end

    context 'empty file_path' do
      it { expect { location.get_path_from_metadata_path('') }.to raise_error(ArgumentError) }
    end

    context 'path not in storage location' do
      it {
        expect { location.get_path_from_metadata_path('/some/other/path/file') }.to raise_error(ArgumentError,
          /Metadata path must be contained by this location/)
      }
    end

    context 'valid path' do
      it {
        expect(location.get_path_from_metadata_path('/metadata/path/sub/myfile.txt-llmd.yaml'))
          .to eq '/file/path/sub/myfile.txt'
      }
    end

    context 'path containing repeated path' do
      it {
        expect(location.get_path_from_metadata_path('/metadata/path/file/path/myfile.txt-llmd.yaml'))
          .to eq '/file/path/file/path/myfile.txt'
      }
    end

    context 'directory file_path' do
      it {
        expect(location.get_path_from_metadata_path('/metadata/path/file/path/subdir/'))
          .to eq '/file/path/file/path/subdir/'
      }
    end
  end

  describe '.available?' do
    context 'with non-existent path' do
      # Ensuring that the directory does not exist
      let(:path_dir) { FileUtils.rmdir(Dir.mktmpdir('path'))[0] }
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:location) { build(:storage_location, path: path_dir, metadata_path: md_dir) }

      after(:each) do
        FileUtils.rmdir(md_dir)
      end

      it { expect { location.available? }.to raise_error(Longleaf::StorageLocationUnavailableError, /Path does not exist/) }
    end

    context 'with non-directory path' do
      let(:file_path) { Tempfile.new('file_as_path').path }
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:location) { build(:storage_location, path: file_path, metadata_path: md_dir) }

      after(:each) do
        File.delete(file_path)
        FileUtils.rmdir(md_dir)
      end

      it {
        expect { location.available? }.to raise_error(Longleaf::StorageLocationUnavailableError,\
          /Path does not exist or is not a directory/)
      }
    end

    context 'with non-existent metadata path' do
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:md_dir) { FileUtils.rmdir(Dir.mktmpdir('metadata'))[0] }
      let(:location) { build(:storage_location, path: path_dir, metadata_path: md_dir) }

      after(:each) do
        FileUtils.rmdir(path_dir)
      end

      it {
        expect { location.available? }.to raise_error(Longleaf::StorageLocationUnavailableError,\
          /Metadata path does not exist/)
      }
    end

    context 'with valid paths' do
      let(:path_dir) { Dir.mktmpdir('path') }
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:location) { build(:storage_location, path: path_dir, metadata_path: md_dir) }

      after(:each) do
        FileUtils.rmdir([path_dir, md_dir])
      end

      it { expect { location.available? }.to_not raise_error }
    end
  end

  describe '.relativize' do
    context 'path not in location' do
      let(:location) { build(:storage_location) }

      let(:file_path) { '/some/other/path/file' }

      it { expect { location.relativize(file_path) }.to raise_error(ArgumentError, /must be contained by this location/ ) }
    end

    context 'relative path' do
      let(:location) { build(:storage_location) }

      let(:file_path) { 'path/file' }

      it { expect(location.relativize(file_path)).to eq file_path }
    end

    context 'path in location' do
      let(:location) { build(:storage_location) }

      let(:file_path) { '/file/path/sub/myfile.txt' }

      it { expect(location.relativize(file_path)).to eq 'sub/myfile.txt' }
    end
  end

  describe '.contains?' do
    let(:location) { build(:storage_location) }

    context 'path in location' do
      let(:file_path) { '/file/path/sub/myfile.txt' }

      it { expect(location.contains?(file_path)).to be true }
    end

    context 'path not in location' do
      let(:file_path) { '/other/path/to/somefile.txt' }

      it { expect(location.contains?(file_path)).to be false }
    end
  end

  describe '.type' do
    let(:location) { build(:storage_location) }

    it { expect(location.type).to eq 'filesystem' }
  end
end
