require 'spec_helper'
require 'longleaf/services/metadata_persistence_manager'
require 'longleaf/indexing/index_manager'
require 'longleaf/models/metadata_record'
require 'longleaf/models/md_fields'
require 'yaml'
require 'tempfile'
require 'tmpdir'

describe Longleaf::MetadataPersistenceManager do
  let(:index_manager) { instance_double('Longleaf::IndexManager') }
  
  describe '.persist' do
    context 'without index configured' do
      let(:md_manager) { Longleaf::MetadataPersistenceManager.new(index_manager) }
      
      context 'with metadata record' do
        let(:md_rec) { instance_double('Longleaf::MetadataRecord') }
        let(:file_rec) { build(:file_record, metadata_record: md_rec) }
        
        it 'triggers serialization to disk, does not index' do
          expect(index_manager).to receive(:using_index?).and_return(false)
          expect(index_manager).to_not receive(:index)
        
          expect(Longleaf::MetadataSerializer).to receive(:write).with(metadata: md_rec,
              file_path: '/metadata/path/file-llmd.yaml',
              digest_algs: anything
            )
        
          md_manager.persist(file_rec)
        end
      end
      
      context 'without metadata record' do
        let(:file_rec) { build(:file_record, metadata_record: nil) }
        
        it { expect { md_manager.persist(file_rec) }.to raise_error(Longleaf::MetadataError) }
      end
    end
    
    context 'configured with metadata index' do
      let(:md_rec) { instance_double('Longleaf::MetadataRecord') }
      let(:file_rec) { build(:file_record, metadata_record: md_rec) }
      
      let(:md_manager) { Longleaf::MetadataPersistenceManager.new(index_manager) }
      
      it 'triggers serialization to disk and indexing' do
        expect(index_manager).to receive(:using_index?).and_return(true)
        expect(index_manager).to receive(:index).with(file_rec)
        
        expect(Longleaf::MetadataSerializer).to receive(:write).with(metadata: md_rec,
            file_path: '/metadata/path/file-llmd.yaml',
            digest_algs: anything
          )
        
        md_manager.persist(file_rec)
      end
    end
  end
end