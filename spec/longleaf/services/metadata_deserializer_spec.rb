require 'spec_helper'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/models/metadata_record'
require 'longleaf/errors'
require 'longleaf/models/md_fields'
require 'yaml'
require 'tempfile'

describe Longleaf::MetadataDeserializer do
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
            MDF::CHECKSUMS => { 'SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83' }
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
        expect(result.properties[MDF::FILE_SIZE]).to eq 1500
        
        expect(result.service('service_1').timestamp).to eq '2018-01-01T01:00:00.000Z'
        expect(result.service('service_2').properties).to be_empty
      end
    end

    context 'without file path' do
      it { expect { Longleaf::MetadataDeserializer.deserialize() }.to raise_error(ArgumentError) }
    end

    context 'with empty file' do
      let(:empty_file) { Tempfile.new('empty') }
      
      it { expect { Longleaf::MetadataDeserializer.deserialize(file_path: empty_file.path) }.to raise_error(Longleaf::MetadataError) }
    end
    
    context 'with non-existent file' do
      invalid_file = nil
      Dir.mktmpdir { |dir| invalid_file = File.join(dir, 'some_file') }

      it 'rejects path' do
        expect { Longleaf::MetadataDeserializer.deserialize(file_path: invalid_file) } \
            .to raise_error(Errno::ENOENT)
      end
    end
  end
end