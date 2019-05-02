require 'spec_helper'
require 'longleaf/services/metadata_serializer'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'
require 'yaml'
require 'tempfile'
require 'tmpdir'

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
        file_size: 1500,
        last_modified: '2018-09-20T13:13:23Z',
        properties: { 'other_prop' => 'value' },
        checksums: { 'SHA1' => '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83' },
        services: { :service_1 => service_1, :service_2 => service_2 } ) }
      
      it 'serializes as yaml' do
        Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file)
        md = YAML.load_file(dest_file)
        
        expect(md.dig(MDF::DATA, MDF::REGISTERED_TIMESTAMP)).to eq '2018-01-01T00:00:00.000Z'
        expect(md.dig(MDF::DATA, MDF::FILE_SIZE)).to eq 1500
        expect(md.dig(MDF::DATA, MDF::LAST_MODIFIED)).to eq '2018-09-20T13:13:23Z'
        expect(md.dig(MDF::DATA, MDF::CHECKSUMS, 'SHA1')).to eq '4e1243bd22c66e76c2ba9eddc1f91394e57f9f83'
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
          expect(IO.read(digest_path)).to eq '4f33fb12b92a6c2f5b24c51a32368f296ccdb844'
        end
      end
      
      context 'with multiple digest algorithms' do
        it 'generates digest sidecar files' do
          Longleaf::MetadataSerializer.write(metadata: record, file_path: dest_file, digest_algs: ['md5', 'sha512'])
          digest_path_md5 = "#{dest_file.path}.md5"
          digest_path_sha512 = "#{dest_file.path}.sha512"

          expect(File.exist?(digest_path_md5)).to be true
          expect(IO.read(digest_path_md5)).to eq '51ffda2dbfdbc7f1dabee110f12cdcf1'
          
          expect(File.exist?(digest_path_sha512)).to be true
          expect(IO.read(digest_path_sha512)).to eq 'c84a0e05e64082e8fb06162dac465b150a9bfcec440927ef66b8876968ce79a43c10b2ac894f040c2351f861f3427f50e4e37b1a5a072e84e9aa0fabc5a8b845'
        end
      end
    end
    
    context 'with missing parents' do
      let(:base_dest_path) { Dir.mktmpdir }
      let(:nested_dest_path) { File.join(base_dest_path, 'path', 'to', 'md_file')}
      
      let(:record) { build(:metadata_record,
        registered: '2018-01-01T00:00:00.000Z',
        services: { :service_1 => build(:service_record) } ) }
      
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
        expect { Longleaf::MetadataSerializer.write(
            metadata: record, file_path: dest_file, format: 'other') } \
          .to raise_error(ArgumentError)
      end
    end
    
    context 'with invalid file path' do
      let(:record) { build(:metadata_record) }
      
      let(:invalid_file) { File.join(dest_file, 'some_file')}
      
      it 'rejects path' do
        expect { Longleaf::MetadataSerializer.write(metadata: record, file_path: invalid_file) } \
            .to raise_error(SystemCallError)
      end
    end
  end
end