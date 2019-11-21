require 'spec_helper'
require 'tmpdir'
require 'longleaf/models/filesystem_metadata_location'
require 'longleaf/errors'
require 'fileutils'
require 'tempfile'

describe Longleaf::FilesystemMetadataLocation do
  describe '.initialize' do
    context 'with no config' do
      it { expect { build(:metadata_location, config: nil) }.to raise_error(ArgumentError) }
    end
    context 'with no path' do
      it { expect { build(:metadata_location, path: nil) }.to raise_error(ArgumentError) }
    end
  end

  describe '.path' do
    let(:location) { build(:metadata_location) }

    it { expect(location.path).to eq '/metadata/path/' }
  end

  describe '.metadata_path_for' do
    let(:location) { build(:metadata_location) }

    context 'absolute path' do
      let(:file_path) { '/some/path/to/file' }

      it { expect { location.metadata_path_for(file_path) }.to raise_error(ArgumentError, /File path must be relative/ ) }
    end

    context 'nil path' do
      let(:file_path) { nil }

      it { expect { location.metadata_path_for(file_path) }.to raise_error(ArgumentError, /file_path parameter is required/ ) }
    end

    context 'empty path' do
      let(:file_path) { '' }

      it { expect(location.metadata_path_for(file_path)).to eq '/metadata/path/' }
    end

    context 'relative file path' do
      let(:file_path) { 'to/file.txt' }

      it { expect(location.metadata_path_for(file_path)).to eq '/metadata/path/to/file.txt-llmd.yaml' }
    end

    context 'relative directory path' do
      let(:file_path) { 'to/directory/' }

      it { expect(location.metadata_path_for(file_path)).to eq '/metadata/path/to/directory/' }
    end
  end

  describe '.digests' do
    context 'with nil digests' do
      let(:location) { build(:metadata_location, digests: nil) }

      it { expect(location.digests).to eq [] }
    end

    context 'with no digests' do
      let(:location) { build(:metadata_location, digests: []) }

      it { expect(location.digests).to eq [] }
    end

    context 'with string digest' do
      let(:location) { build(:metadata_location, digests: 'sha1') }

      it { expect(location.digests).to contain_exactly('sha1') }
    end

    context 'with array digest' do
      let(:location) { build(:metadata_location, digests: ['sha1']) }

      it { expect(location.digests).to contain_exactly('sha1') }
    end

    context 'with non-normalized case array digest' do
      let(:location) { build(:metadata_location, digests: ['SHA1', 'Sha512']) }

      it { expect(location.digests).to contain_exactly('sha1', 'sha512') }
    end

    context 'with multiple digests' do
      let(:location) { build(:metadata_location, digests: ['sha1', 'sha512']) }

      it { expect(location.digests).to contain_exactly('sha1', 'sha512') }
    end

    context 'with invalid digest' do
      let(:location) { build(:metadata_location, digests: ['indigestion']) }

      it { expect { location.get_metadata_path_for }.to raise_error(Longleaf::InvalidDigestAlgorithmError) }
    end
  end

  describe '.relativize' do
    let(:location) { build(:metadata_location) }

    context 'path not in location' do
      let(:file_path) { '/some/other/path/file' }

      it { expect { location.relativize(file_path) }.to raise_error(ArgumentError, /must be contained by this location/ ) }
    end

    context 'relative path' do
      let(:file_path) { 'path/file' }

      it { expect(location.relativize(file_path)).to eq file_path }
    end

    context 'path in location' do
      let(:file_path) { '/metadata/path/sub/myfile.txt-llmd.yaml' }

      it { expect(location.relativize(file_path)).to eq 'sub/myfile.txt-llmd.yaml' }
    end
  end

  describe '.relative_file_path_for' do
    let(:location) { build(:metadata_location) }

    context 'path not in location' do
      let(:md_path) { '/some/other/path/file.txt-llmd.yaml' }

      it { expect { location.relative_file_path_for(md_path) }.to raise_error(ArgumentError, /must be contained by this location/ ) }
    end

    context 'relative path' do
      let(:md_path) { 'to/file.txt-llmd.yaml' }

      it { expect(location.relative_file_path_for(md_path)).to eq 'to/file.txt' }
    end

    context 'absolute path in location' do
      let(:md_path) { '/metadata/path/to/file.txt-llmd.yaml' }

      it { expect(location.relative_file_path_for(md_path)).to eq 'to/file.txt' }
    end

    context 'directory in location' do
      let(:md_path) { '/metadata/path/to/directory/' }

      it { expect(location.relative_file_path_for(md_path)).to eq 'to/directory/' }
    end
  end

  describe '.contains?' do
    let(:location) { build(:metadata_location) }

    context 'path in location' do
      let(:file_path) { '/metadata/path/sub/myfile.txt' }

      it { expect(location.contains?(file_path)).to be true }
    end

    context 'path not in location' do
      let(:file_path) { '/other/path/to/somefile.txt' }

      it { expect(location.contains?(file_path)).to be false }
    end
  end
end
