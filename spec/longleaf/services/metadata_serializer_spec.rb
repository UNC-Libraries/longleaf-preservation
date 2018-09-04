require 'spec_helper'
require 'longleaf/services/metadata_serializer'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'
require 'yaml'
require 'tempfile'

describe Longleaf::MetadataSerializer do
  MDF ||= Longleaf::MDFields
  
  describe '.write' do
    let(:dest_file) { Tempfile.new('md_file') }
    
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
      let(:service_1) { build(:service_record, timestamp: '2018-01-01T01:00:00.000Z',
          properties: { 'service_prop' => 'value'} ) }
      let(:service_2) { build(:service_record) }
      
      let(:record) { build(:metadata_record,
        registered: '2018-01-01T00:00:00.000Z',
        properties: { MDF::FILE_SIZE => 1500 },
        checksums: { 'SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83' },
        services: { :service_1 => service_1, :service_2 => service_2 } ) }
      
      it 'serializes as yaml' do
        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file)
        md = YAML.load_file(dest_file)
        
        expect(md.dig(MDF::DATA, MDF::REGISTERED_TIMESTAMP)).to eq '2018-01-01T00:00:00.000Z'
        expect(md.dig(MDF::DATA, MDF::FILE_SIZE)).to eq 1500
        expect(md.dig(MDF::DATA, MDF::CHECKSUMS, 'SHA1')).to eq '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
        
        expect(md.dig(MDF::SERVICES, :service_1, MDF::SERVICE_TIMESTAMP)).to eq '2018-01-01T01:00:00.000Z'
        expect(md.dig(MDF::SERVICES, :service_1, 'service_prop')).to eq 'value'
        
        expect(md.dig(MDF::SERVICES, :service_2)).to be_empty
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
        expect { Longleaf::MetadataSerializer.write(
            metadata: record, file_path: dest_file, format: 'other') } \
          .to raise_error(ArgumentError)
      end
    end
    
    context 'with invalid file path' do
      let(:record) { build(:metadata_record) }
      
      invalid_file = nil
      Dir.mktmpdir { |dir| invalid_file = File.join(dir, 'some_file') }
      
      it 'rejects path' do
        expect { Longleaf::MetadataSerializer.write(metadata: record, file_path: invalid_file) } \
            .to raise_error(Errno::ENOENT)
      end
    end
  end
end