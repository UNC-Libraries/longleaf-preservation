require 'spec_helper'
require 'longleaf/errors'
require 'longleaf/specs/file_helpers'
require 'longleaf/services/service_class_cache'
require 'longleaf/services/application_config_manager'
require 'longleaf/preservation_services/fixity_check_service'

describe Longleaf::ServiceClassCache do
  include Longleaf::FileHelpers
  
  let(:app_manager) { double(Longleaf::ApplicationConfigManager) }
  let(:lib_dir) { make_test_dir(name: 'lib_dir') }
  
  after do
    $LOAD_PATH.delete(lib_dir)
    FileUtils.rm_rf([lib_dir])
  end
  
  describe '.service_class' do
    context 'work_script from standard library script' do
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let(:service_def) { build(:service_definition, work_script: 'fixity_check_service')}
      
      it { expect(class_cache.service_class(service_def)).to eq Longleaf::FixityCheckService }
      
      it "returns class for multiple requests" do
        expect(class_cache.service_class(service_def)).to eq Longleaf::FixityCheckService
        expect(class_cache.service_class(service_def)).to eq Longleaf::FixityCheckService
      end
    end
    
    context 'work_script from allowed external path' do
      before { $LOAD_PATH.unshift(lib_dir) }
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let!(:work_script_file) { create_work_class(lib_dir, 'APresService', 'a_pres_service.rb') }
      let(:service_def) { build(:service_definition, work_script: work_script_file) }
      
      it { expect(class_cache.service_class(service_def).name).to eq 'APresService' }
    end
    
    context 'work_script from disallowed external path' do
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let!(:work_script_file) { create_work_class(lib_dir, 'APresService', 'a_pres_service.rb') }
      let(:service_def) { build(:service_definition, work_script: work_script_file) }
      
      it { expect{ class_cache.service_class(service_def) }.to raise_error(Longleaf::ConfigurationError) }
    end
    
    context 'work_script does not match class name' do
      before { $LOAD_PATH.unshift(lib_dir) }
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let!(:work_script_file) { create_work_class(lib_dir, 'SecretService1', 'pres_service1.rb') }
      let(:service_def) { build(:service_definition, work_script: work_script_file) }
      
      it { expect{ class_cache.service_class(service_def) }.to raise_error(Longleaf::ConfigurationError) }
    end
    
    context 'work_script with correct work_class' do
      before { $LOAD_PATH.unshift(lib_dir) }
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let!(:work_script_file) { create_work_class(lib_dir, 'SecretService2', 'pres_service2.rb') }
      let(:service_def) { build(:service_definition, work_script: work_script_file, work_class: 'SecretService2') }
      
      it { expect(class_cache.service_class(service_def).name).to eq 'SecretService2' }
    end
    
    context 'work_script with work_class containing module' do
      before { $LOAD_PATH.unshift(lib_dir) }
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let!(:work_script_file) { create_work_class(lib_dir, 'SecretService3', 'pres_service3.rb', 'Myservices') }
      let(:service_def) { build(:service_definition, work_script: work_script_file, work_class: 'Myservices::SecretService3') }
      
      it { expect(class_cache.service_class(service_def).name).to eq 'Myservices::SecretService3' }
    end
    
    context 'work_script with incorrect work_class' do
      before { $LOAD_PATH.unshift(lib_dir) }
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let!(:work_script_file) { create_work_class(lib_dir, 'SecretService4', 'pres_service2.rb') }
      let(:service_def) { build(:service_definition, work_script: work_script_file, work_class: 'WhoaService') }
      
      it { expect{ class_cache.service_class(service_def) }.to raise_error(Longleaf::ConfigurationError) }
    end
    
    context 'work_script does not exist' do
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let(:service_def) { build(:service_definition, work_script: 'imaginary_service')}
      
      it { expect{ class_cache.service_class(service_def) }.to raise_error(Longleaf::ConfigurationError) }
    end
  end
  
  describe '.service_instance' do
    context 'work_script from standard library script' do
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let(:service_def) {
        properties = Hash.new
        properties[Longleaf::ServiceFields::DIGEST_ALGORITHMS] = ['md5']
        build(:service_definition, work_script: 'fixity_check_service', properties: properties)
      }
      
      it { expect(class_cache.service_instance(service_def)).to be_a(Longleaf::FixityCheckService) }
    end
    
    context 'work_script from allowed external path' do
      before { $LOAD_PATH.unshift(lib_dir) }
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let!(:work_script_file) { create_work_class(lib_dir, 'APresService', 'a_pres_service.rb') }
      let(:service_def) { build(:service_definition, work_script: work_script_file) }
      
      it { expect(class_cache.service_instance(service_def).class.name).to eq 'APresService' }
    end
    
    context 'work_script from disallowed external path' do
      let(:class_cache) { build(:service_class_cache, location_manager: app_manager) }
      let!(:work_script_file) { create_work_class(lib_dir, 'AnotherPresService', 'another_pres_service.rb') }
      let(:service_def) { build(:service_definition, work_script: work_script_file) }
      
      it { expect{ class_cache.service_instance(service_def) }.to raise_error(Longleaf::ConfigurationError) }
    end
  end
end