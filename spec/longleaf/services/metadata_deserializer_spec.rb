require 'spec_helper'
require 'longleaf/specs/file_helpers'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/models/metadata_record'
require 'longleaf/errors'
require 'longleaf/models/md_fields'
require 'yaml'
require 'tempfile'

describe Longleaf::MetadataDeserializer do
  include Longleaf::FileHelpers
  MDF ||= Longleaf::MDFields

  describe '.deserialize' do
    context 'from empty record' do
      let(:md_no_props) {
        {
          MDF::DATA => {},
          MDF::SERVICES => {}
        }
      }
      let(:no_props_file) { Tempfile.new('no_props') }
      before(:each) do
        File.write(no_props_file, md_no_props.to_yaml)
      end

      it 'deserializes from yaml' do
        result = Longleaf::MetadataDeserializer.deserialize(file_path: no_props_file)

        expect(result.properties).to be_empty
        expect(result.registered).to be_nil
        expect(result.list_services).to be_empty
      end
    end

    context 'from populated record' do
      let(:md_with_props) {
        {
          MDF::DATA => {
            MDF::REGISTERED_TIMESTAMP => '2018-01-01T00:00:00.000Z',
            MDF::FILE_SIZE => 1500,
            MDF::CHECKSUMS => { 'SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83' },
            MDF::LAST_MODIFIED => '2016-01-01T20:38:45Z',
            'special' => 'value'
          },
          MDF::SERVICES => {
            'service_1' => {
              MDF::SERVICE_TIMESTAMP => '2018-01-01T01:00:00.000Z'
            },
            'service_2' => {}
          }
        }
      }
      let(:populated_file) { Tempfile.new('populated') }

      before(:each) do
        File.write(populated_file, md_with_props.to_yaml)
      end

      it 'deserializes from yaml' do
        result = Longleaf::MetadataDeserializer.deserialize(file_path: populated_file)

        expect(result.registered).to eq '2018-01-01T00:00:00.000Z'
        expect(result.checksums).to include('SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83')
        expect(result.file_size).to eq 1500
        expect(result.last_modified).to eq '2016-01-01T20:38:45Z'
        expect(result.properties['special']).to eq 'value'

        expect(result.service('service_1').timestamp).to eq '2018-01-01T01:00:00.000Z'
        expect(result.service('service_2').properties).to be_empty
      end
    end

    context 'without file path' do
      it { expect { Longleaf::MetadataDeserializer.deserialize() }.to raise_error(ArgumentError) }
    end

    context 'with empty file' do
      let(:md_file) { create_test_file(name: 'empty') }

      it { expect { Longleaf::MetadataDeserializer.deserialize(file_path: md_file) }.to raise_error(Longleaf::MetadataError) }
    end

    context 'with non-existent file' do
      invalid_file = nil
      Dir.mktmpdir { |dir| invalid_file = File.join(dir, 'some_file') }

      it 'rejects path' do
        expect { Longleaf::MetadataDeserializer.deserialize(file_path: invalid_file) } \
            .to raise_error(Errno::ENOENT)
      end
    end

    context 'with invalid file' do
      let(:md_file) { create_test_file(content: 'busted : yml : file') }

      it { expect { Longleaf::MetadataDeserializer.deserialize(file_path: md_file) }.to raise_error(Longleaf::MetadataError) }
    end
  end
end
