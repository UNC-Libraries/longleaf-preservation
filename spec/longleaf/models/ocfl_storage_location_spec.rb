require 'spec_helper'

if RUBY_ENGINE == 'jruby'
  require 'longleaf/models/ocfl_storage_location'
  require 'longleaf/models/app_fields'
  require 'longleaf/services/metadata_serializer'
  require 'fileutils'
  require 'tmpdir'

  describe Longleaf::OcflStorageLocation do

    OCFL_OBJECT_REL_PATH ||= '141/964/af8/141964af842132b7a706ed010474c410514b472acc0d7d8f805c23e748578b8b'

    describe '.initialize' do
      context 'with no config' do
        it { expect { build(:ocfl_storage_location, config: nil) }.to raise_error(ArgumentError) }
      end

      context 'with no metadata location' do
        it { expect { build(:ocfl_storage_location, md_loc: nil) }.to raise_error(ArgumentError) }
      end

      context 'with no name' do
        it { expect { build(:ocfl_storage_location, name: nil) }.to raise_error(ArgumentError) }
      end

      context 'with valid config' do
        it { expect { build(:ocfl_storage_location) }.not_to raise_error }
      end

      context 'with explicit digest algorithm' do
        it { expect { build(:ocfl_storage_location, digest_algorithm: 'sha256') }.not_to raise_error }
      end

      context 'with no work_dir' do
        it { expect { build(:ocfl_storage_location, work_dir: nil) }.to raise_error(ArgumentError, /work_dir/) }
      end
    end

    describe '.type' do
      let(:location) { build(:ocfl_storage_location) }

      it { expect(location.type).to eq 'ocfl' }
    end

    describe '.ocfl_repository' do
      context 'with default config against the fixture root' do
        let(:location) { build(:ocfl_storage_location) }

        it 'returns a non-nil repository' do
          expect(location.ocfl_repository).not_to be_nil
        end

        it 'returns the same instance on repeated calls' do
          repo = location.ocfl_repository
          expect(location.ocfl_repository).to be(repo)
        end

        it 'can enumerate the objects in the fixture' do
          ids = []
          location.ocfl_repository.list_object_ids.for_each { |id| ids << id.to_s }
          expect(ids).to contain_exactly('info:fedora', 'info:fedora/test_object')
        end

        it 'reports that known objects exist' do
          expect(location.ocfl_repository.contains_object('info:fedora')).to be true
          expect(location.ocfl_repository.contains_object('info:fedora/test_object')).to be true
        end

        it 'reports that an unknown object does not exist' do
          expect(location.ocfl_repository.contains_object('info:fedora/nonexistent')).to be false
        end
      end

      context 'with verify_inventory disabled' do
        let(:location) { build(:ocfl_storage_location, verify_inventory: false) }

        it 'returns a usable repository' do
          expect(location.ocfl_repository).not_to be_nil
        end

        it 'can locate objects' do
          expect(location.ocfl_repository.contains_object('info:fedora')).to be true
        end
      end

      context 'with an unsupported digest algorithm' do
        let(:location) { build(:ocfl_storage_location, digest_algorithm: 'sha3-256') }

        it 'raises an ArgumentError when the repository is first accessed' do
          expect { location.ocfl_repository }.to raise_error(ArgumentError, /sha3-256/)
        end
      end
    end

    describe '.get_metadata_path_for' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:location) { build(:ocfl_storage_location, metadata_path: md_dir) }

      after { FileUtils.rm_rf(md_dir) }

      context 'with an OCFL object directory path' do
        it 'returns the sidecar metadata path without requiring explicit object_type' do
          object_path = File.join(location.path, OCFL_OBJECT_REL_PATH) + '/'
          expected = File.join(md_dir, OCFL_OBJECT_REL_PATH) + Longleaf::MetadataSerializer.metadata_suffix
          expect(location.get_metadata_path_for(object_path)).to eq expected
        end
      end

      context 'with the storage root path' do
        it 'returns the metadata root directory to allow directory traversal' do
          expect(location.get_metadata_path_for(location.path)).to eq location.metadata_location.path
        end
      end
    end

    describe '.get_path_from_metadata_path' do
      let(:md_dir) { Dir.mktmpdir('metadata') }
      let(:location) { build(:ocfl_storage_location, metadata_path: md_dir) }

      after { FileUtils.rm_rf(md_dir) }

      context 'with an OCFL sidecar metadata path' do
        it 'returns the OCFL object directory path with a trailing slash' do
          sidecar_path = File.join(md_dir, OCFL_OBJECT_REL_PATH) + Longleaf::MetadataSerializer.metadata_suffix
          expected = File.join(location.path, OCFL_OBJECT_REL_PATH) + '/'
          expect(location.get_path_from_metadata_path(sidecar_path)).to eq expected
        end
      end
    end
  end
end
