require 'spec_helper'
require 'longleaf/models/s3_storage_location'
require 'longleaf/models/metadata_location'
require 'longleaf/helpers/s3_uri_helper'
require 'longleaf/errors'
require 'tmpdir'

describe Longleaf::S3StorageLocation do
  describe '.initialize' do
    context 'with no config' do
      it { expect { build(:s3_storage_location, config: nil) }.to raise_error(ArgumentError) }
    end
    context 'with no metadata location' do
      it { expect { build(:s3_storage_location, md_loc: nil) }.to raise_error(ArgumentError) }
    end
    context 'with no name' do
      it { expect { build(:s3_storage_location, name: nil) }.to raise_error(ArgumentError) }
    end
    context 'with file path' do
      it { expect { build(:s3_storage_location, path: '/path/to/my/loc1') }.to raise_error(ArgumentError) }
    end
    context 'with file uri' do
      it { expect { build(:s3_storage_location, path: 'file:///path/to/my/loc1') }.to raise_error(ArgumentError, /Invalid scheme/) }
    end
    context 's3 uri without bucket' do
      it { expect { build(:s3_storage_location, path: 's3://s3.amazonaws.com/') }.to raise_error(ArgumentError) }
    end
  end

  describe '.s3_bucket' do
    context 'bucket in virtual host style with region in uri' do
      let(:loc1) { build(:s3_storage_location, path: 'http://example.s3-my-region-amazonaws.com/') }
      it 'uses region from uri' do
        expect(Longleaf::S3UriHelper.extract_region(loc1.s3_bucket.url)).to eq 'my-region'
        expect(loc1.s3_bucket.name).to eq 'example'
      end
    end
    context 'bucket in path style' do
      let(:loc1) { build(:s3_storage_location, path: 'http://s3-my-region-amazonaws.com/pathexample/') }
      it 'uses bucket name from path with region in uri' do
        expect(Longleaf::S3UriHelper.extract_region(loc1.s3_bucket.url)).to eq 'my-region'
        expect(loc1.s3_bucket.name).to eq 'pathexample'
      end
    end
    context 'region from config' do
      let(:loc1) { build(:s3_storage_location, path: 'http://example.s3-amazonaws.com/', options: {
        :stub_responses => true,
        :region => 'my-real-region'
      } ) }
      it 'uses region from config' do
        expect(Longleaf::S3UriHelper.extract_region(loc1.s3_bucket.url)).to eq 'my-real-region'
        expect(loc1.s3_bucket.name).to eq 'example'
      end
    end
    context 'region in uri and config' do
      let(:loc1) { build(:s3_storage_location, path: 'http://example.s3-uri-region-amazonaws.com/', options: {
        :stub_responses => true,
        :region => 'my-config-region'
      } ) }
      it 'uses region from config' do
        expect(Longleaf::S3UriHelper.extract_region(loc1.s3_bucket.url)).to eq 'my-config-region'
        expect(loc1.s3_bucket.name).to eq 'example'
      end
    end
  end

  describe '.get_path_from_metadata_path' do
    let(:loc1) { build(:s3_storage_location) }

    context 'nil file_path' do
      it { expect { loc1.get_path_from_metadata_path(nil) }.to raise_error(ArgumentError) }
    end

    context 'empty file_path' do
      it { expect { loc1.get_path_from_metadata_path('') }.to raise_error(ArgumentError) }
    end

    context 'valid path' do
      it {
        expect(loc1.get_path_from_metadata_path('/metadata/path/sub/myfile.txt-llmd.yaml'))
          .to eq 'https://example.s3-amazonaws.com/path/sub/myfile.txt'
      }
    end
  end

  describe '.available?' do
    let(:md_dir) { Dir.mktmpdir('metadata') }
    let(:loc1) { build(:s3_storage_location, metadata_path: md_dir) }

    context 'bucket does not exist' do
      before do
        loc1.s3_client.stub_responses(:head_bucket, 'NotFound')
      end
      it { expect { loc1.available? }.to raise_error(Longleaf::StorageLocationUnavailableError, /bucket example does not exist/) }
    end

    context 'bucket does exist' do
      it { expect { loc1.available? }.to_not raise_error }
    end

    context 'metadata location does not exist' do
      before do
        FileUtils.rmdir(md_dir)
      end
      it { expect { loc1.available? }.to raise_error(Longleaf::StorageLocationUnavailableError, /Metadata path does not exist/) }
    end
  end

  describe '.relativize' do
    let(:loc1) { build(:s3_storage_location) }

    context 'empty path' do
      it { expect(loc1.relativize('')).to eq '' }
    end

    context 'nil path' do
      it { expect { loc1.relativize(nil) }.to raise_error(ArgumentError) }
    end

    context 'starts with path' do
      it { expect(loc1.relativize('https://example.s3-amazonaws.com/path/subdir/file.txt')).to eq 'subdir/file.txt' }
    end

    context 'relative path' do
      it { expect(loc1.relativize('subdir/file.txt')).to eq 'subdir/file.txt' }
    end

    context 'outside of base path' do
      it { expect { loc1.relativize('https://example.s3-amazonaws.com/different/path/file.txt') }.to raise_error(ArgumentError) }
    end

    context 'another bucket' do
      it { expect { loc1.relativize('https://anotherbucket.s3-amazonaws.com/path/subdir/file.txt') }.to raise_error(ArgumentError) }
    end
  end

  describe '.get_metadata_path_for' do
    let(:loc1) { build(:s3_storage_location) }

    context 'valid path' do
      it 'returns path' do
        expect(loc1.get_metadata_path_for('https://example.s3-amazonaws.com/path/subdir/file.txt'))
          .to eq '/metadata/path/subdir/file.txt-llmd.yaml'
      end
    end

    context 'path to directory' do
      it 'returns directory path' do
        expect(loc1.get_metadata_path_for('https://example.s3-amazonaws.com/path/subdir/'))
          .to eq '/metadata/path/subdir/'
      end
    end

    context 'path outside location' do
      it 'returns directory path' do
        expect { loc1.get_metadata_path_for('https://differentbucket.s3-amazonaws.com/path/subdir/') }
          .to raise_error(ArgumentError)
      end
    end
  end

  describe '.contains?' do
    let(:loc1) { build(:s3_storage_location) }

    context 'path in location' do
      let(:file_path) { 'https://example.s3-amazonaws.com/path/subdir/file.txt' }

      it { expect(loc1.contains?(file_path)).to be true }
    end

    context 'path not in location' do
      let(:file_path) { '/other/path/to/somefile.txt' }

      it { expect(loc1.contains?(file_path)).to be false }
    end
  end

  describe '.type' do
    let(:location) { build(:s3_storage_location) }

    it { expect(location.type).to eq 's3' }
  end
end
