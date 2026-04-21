require 'spec_helper'

if RUBY_ENGINE == 'jruby'
  require 'longleaf/models/ocfl_storage_location'
  require 'longleaf/models/app_fields'

  describe Longleaf::OcflStorageLocation do
    OCFL_FIXTURE_PATH = File.expand_path('../../fixtures/ocfl-root', __dir__) + File::SEPARATOR

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
  end
end
