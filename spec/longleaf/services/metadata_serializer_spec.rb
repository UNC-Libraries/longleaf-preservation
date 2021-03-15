require 'spec_helper'
require 'longleaf/services/metadata_serializer'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'
require 'longleaf/specs/file_helpers'
require 'yaml'
require 'fileutils'

describe Longleaf::MetadataSerializer do
  include Longleaf::FileHelpers
  MDF ||= Longleaf::MDFields

  describe '.write' do
    let(:dest_dir) { make_test_dir }
    let(:dest_file) { File.new(create_test_file(dir: dest_dir, name: 'md_file.yml')) }

    after do
      FileUtils.rm_rf([dest_dir])
    end

    context 'with empty record' do
      let(:record) { build(:metadata_record) }

      it 'serializes as yaml' do
        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file)
        md = YAML.load_file(dest_file)

        expect(md[MDF::DATA]).to be_empty
        expect(md[MDF::SERVICES]).to be_empty
      end
    end

    context 'with populated record' do
      let(:service_1) {
        build(:service_record, timestamp: '2018-01-01T01:00:00.000Z',
          properties: { 'service_prop' => 'value'} )
      }
      let(:service_2) { build(:service_record) }

      let(:record) {
        build(:metadata_record,
        registered: '2018-01-01T00:00:00.000Z',
        file_size: 1500,
        last_modified: '2018-09-20T13:13:23Z',
        properties: { 'other_prop' => 'value' },
        checksums: { 'SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83' },
        services: { :service_1 => service_1, :service_2 => service_2 } )
      }

      it 'serializes as yaml' do
        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file)
        md = YAML.load_file(dest_file)

        expect(md.dig(MDF::DATA, MDF::REGISTERED_TIMESTAMP)).to eq '2018-01-01T00:00:00.000Z'
        expect(md.dig(MDF::DATA, MDF::FILE_SIZE)).to eq 1500
        expect(md.dig(MDF::DATA, MDF::LAST_MODIFIED)).to eq '2018-09-20T13:13:23Z'
        expect(md.dig(MDF::DATA, MDF::CHECKSUMS, 'sha1')).to eq '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
        expect(md.dig(MDF::DATA, 'other_prop')).to eq 'value'

        expect(md.dig(MDF::SERVICES, :service_1, MDF::SERVICE_TIMESTAMP)).to eq '2018-01-01T01:00:00.000Z'
        expect(md.dig(MDF::SERVICES, :service_1, 'service_prop')).to eq 'value'

        expect(md[MDF::SERVICES].key?(:service_2)).to be false
      end

      context 'with digest sha1 algorithm' do
        it 'generates sha1 digest sidecar' do
          Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['sha1'])
          digest_path = "#{dest_file.path}.sha1"

          expect(File.exist?(digest_path)).to be true
          expect(IO.read(digest_path)).to eq '1b3ff89cbdc5b6ea85c981f78111aae377dfbea1'
        end
      end

      context 'with multiple digest algorithms' do
        it 'generates digest sidecar files' do
          Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['md5', 'sha512'])
          digest_path_md5 = "#{dest_file.path}.md5"
          digest_path_sha512 = "#{dest_file.path}.sha512"

          expect(File.exist?(digest_path_md5)).to be true
          expect(IO.read(digest_path_md5)).to eq 'cb2c5373318988c9b681a79f67552a2c'

          expect(File.exist?(digest_path_sha512)).to be true
          expect(IO.read(digest_path_sha512)).to eq '5b77efa7db605378a42b273bc0650df1fd7e5db4ab2e735ee8afc7c9a0e1c4836d7bfb942416c83f21def18538937f99051c467504616f2a2a07bcee48fa3031'
        end
      end

      it 'updates metadata and digests on subsequent calls' do
        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['sha1'])

        # update a service before re-serializing
        record.update_service_as_performed("some_service")

        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['sha1'])

        md = YAML.load_file(dest_file)

        expect(md.dig(MDF::SERVICES)).to include("some_service")
        # Just the new metadata file and its digest should exist
        expect(Dir[File.join(dest_dir, '*')].length).to eq 2

        # New digest file must exist
        digest_path = "#{dest_file.path}.sha1"
        expect(File.exist?(digest_path)).to be true
        # digest must have changed
        expect(IO.read(digest_path)).to_not eq '1b3ff89cbdc5b6ea85c981f78111aae377dfbea1'
      end

      it 'updates metadata and removes out of date digests on subsequent calls' do
        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['sha1', 'md5'])
        # Should be 2 digest files at this point
        expect(Dir[File.join(dest_dir, '*')].length).to eq 3

        # update a service before re-serializing
        record.update_service_as_performed("some_service")

        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['sha1'])

        md = YAML.load_file(dest_file)

        expect(md.dig(MDF::SERVICES)).to include("some_service")
        # Just the new metadata file and one digest should exist now
        expect(Dir[File.join(dest_dir, '*')].length).to eq 2

        # New digest file must exist
        digest_path = "#{dest_file.path}.sha1"
        expect(File.exist?(digest_path)).to be true
        # digest must have changed
        expect(IO.read(digest_path)).to_not eq '1b3ff89cbdc5b6ea85c981f78111aae377dfbea1'
      end

      it 'preserves original during failed update' do
        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['sha1'])

        # update a service before re-serializing
        record.update_service_as_performed("some_service")

        allow_any_instance_of(Tempfile).to receive(:write) { raise Errno::ENOSPC }

        expect { Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['sha1'])} \
            .to raise_error(Errno::ENOSPC)

        md = YAML.load_file(dest_file)

        expect(md.dig(MDF::SERVICES)).to_not include("some_service")
        # Just the original metadata file and its digest should exist
        expect(Dir[File.join(dest_dir, '*')].length).to eq 2

        # Expect original digest to still be present
        digest_path = "#{dest_file.path}.sha1"
        expect(File.exist?(digest_path)).to be true
        expect(IO.read(digest_path)).to eq '1b3ff89cbdc5b6ea85c981f78111aae377dfbea1'
      end

      it 'preserves original and cleans up when fail during rename' do
        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['sha1'])

        # update a service before re-serializing
        record.update_service_as_performed("some_service")

        # Fail during temp file move, not during original file move
        allow(File).to receive(:rename).with(dest_file.path, anything()).and_call_original
        allow(File).to receive(:rename).once { raise Errno::ENOLCK }

        expect { Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['sha1'])} \
            .to raise_error(Errno::ENOLCK)

        md = YAML.load_file(dest_file)

        expect(md.dig(MDF::SERVICES)).to_not include("some_service")
        # Just the original metadata file and its digest should exist
        expect(Dir[File.join(dest_dir, '*')].length).to eq 2
        expect(File.exist?(dest_file)).to be true

        # Expect original digest to still be present
        digest_path = "#{dest_file.path}.sha1"
        expect(File.exist?(digest_path)).to be true
        expect(IO.read(digest_path)).to eq '1b3ff89cbdc5b6ea85c981f78111aae377dfbea1'
      end
    end

    context 'with missing parents' do
      let(:base_dest_path) { Dir.mktmpdir }
      let(:nested_dest_path) { File.join(base_dest_path, 'path', 'to', 'md_file') }

      let(:record) {
        build(:metadata_record,
        registered: '2018-01-01T00:00:00.000Z',
        services: { :service_1 => build(:service_record) } )
      }

      after do
        FileUtils.remove_entry base_dest_path
      end

      it 'creates missing parents and serializes as yaml' do
        Longleaf::MetadataSerializer.write(metadata: record, file_path: nested_dest_path)
        md = YAML.load_file(nested_dest_path)

        expect(md.dig(MDF::DATA, MDF::REGISTERED_TIMESTAMP)).to eq '2018-01-01T00:00:00.000Z'
        expect(md[MDF::SERVICES].key?(:service_1)).to be false
      end
    end

    context 'without file path' do
      let(:record) { build(:metadata_record) }

      it { expect { Longleaf::MetadataSerializer.write(metadata: record) }.to raise_error(ArgumentError) }
    end

    context 'without metadata record' do
      it { expect { Longleaf::MetadataSerializer.write(file_path: dest_file) }.to raise_error(ArgumentError) }
    end

    context 'with invalid metadata object type' do
      it 'rejects metadata type' do
        expect { Longleaf::MetadataSerializer.write(metadata: 'bad', file_path: dest_file) } \
          .to raise_error(ArgumentError)
      end
    end

    context 'with invalid serialization format' do
      let(:record) { build(:metadata_record) }

      it 'rejects format' do
        expect {
          Longleaf::MetadataSerializer.write(
            metadata: record, file_path: dest_file, format: 'other')
        }         \
          .to raise_error(ArgumentError)
      end
    end

    context 'with invalid file path' do
      let(:record) { build(:metadata_record) }

      let(:invalid_file) { File.join(dest_file, 'some_file') }

      it 'rejects path' do
        expect { Longleaf::MetadataSerializer.write(metadata: record, file_path: invalid_file) } \
            .to raise_error(SystemCallError)
      end
    end
  end
end
