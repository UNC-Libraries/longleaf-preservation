require 'spec_helper'
require 'longleaf/errors'
require 'longleaf/preservation_services/file_check_service'
require 'longleaf/models/service_fields'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/metadata_builder'
require 'longleaf/specs/config_builder'
require 'digest'
require 'fileutils'

describe Longleaf::FileCheckService do
  include Longleaf::FileHelpers

  ConfigBuilder ||= Longleaf::ConfigBuilder
  MetadataBuilder ||= Longleaf::MetadataBuilder
  FileCheckService ||= Longleaf::FileCheckService
  PRESERVE_EVENT ||= Longleaf::EventNames::PRESERVE
  PreservationServiceError ||= Longleaf::PreservationServiceError
  
  let(:md_dir) { make_test_dir(name: 'metadata') }
  let!(:path_dir) { make_test_dir(name: 'path') }
  let(:config) { ConfigBuilder.new
      .with_services
      .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
      .with_mappings
      .get }
  let(:app_manager) { build(:application_config_manager, config: config) }
  
  after do
    FileUtils.rm_rf([md_dir, md_dir])
  end
  
  describe '.initialize' do
    context 'with service definition' do
      let(:service_def) { build(:service_definition) }
      
      it { expect(FileCheckService.new(service_def, app_manager)).to be_a(FileCheckService) }
    end
  end
  
  describe '.is_applicable?' do
    context 'with service definition' do
      let(:service_def) { build(:service_definition) }
      let(:service) { FileCheckService.new(service_def, app_manager) }
      
      it "returns true for preserve event" do
        expect(service.is_applicable?(PRESERVE_EVENT)).to be true
      end
      
      it "returns false for non-preserve event" do
        expect(service.is_applicable?(Longleaf::EventNames::REGISTER)).to be false
      end
      
      it "returns false for invalid event" do
        expect(service.is_applicable?('nope')).to be false
      end
    end
  end
  
  describe '.perform' do
    let(:service_def) { build(:service_definition) }
    let(:service) { FileCheckService.new(service_def, app_manager) }
    
    let(:file_content) { 'file content' }
    let(:file_rec) { create_registered_file(path_dir, file_content) }
    
    context 'with file matching registered details' do
      it { expect { service.perform(file_rec, PRESERVE_EVENT) }.to_not raise_error }
    end
    
    context 'with file that has been moved' do
      before do
        FileUtils.mv(file_rec.path, File.join(path_dir, 'moved_to_here'))
      end
      
      it 'raises PreservationServiceError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(PreservationServiceError,
            /File does not exist: #{file_rec.path}/)
      end
    end
    
    context 'file content replaced by different equal length string' do
      before do
        sleep(0.01)
        open(file_rec.path, 'w') do |f|
          f << 'content  >:)'
        end
      end
      
      it 'raises PreservationServiceError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(PreservationServiceError,
            /Last modified timestamp for #{file_rec.path} does not match the expected value/)
      end
    end
    
    context 'file size does not match registered value' do
      before do
        allow(file_rec.metadata_record).to receive(:file_size).and_return(999)
      end
      
      it 'raises PreservationServiceError' do
        expect { service.perform(file_rec, PRESERVE_EVENT) }.to raise_error(PreservationServiceError,
            /File size for #{file_rec.path} does not match the expected value: registered = 999 bytes, actual = #{file_content.length} bytes/)
      end
    end
  end
  
  def create_registered_file(path_dir, file_content)
    file_path = create_test_file(dir: path_dir, content: file_content)
    storage_loc = app_manager.location_manager.get_location_by_path(file_path)
    file_rec = build(:file_record, storage_location: storage_loc, file_path: file_path)
    MetadataBuilder.new(file_path: file_path)
        .register_to(file_rec)
    file_rec
  end
end