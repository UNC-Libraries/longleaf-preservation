require 'spec_helper'
require 'longleaf/candidates/service_candidate_locator'
require 'longleaf/candidates/service_candidate_filesystem_iterator'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'longleaf/errors'
require 'fileutils'

describe Longleaf::ServiceCandidateLocator do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  describe '.candidate_iterator' do
    context 'configured without index' do
      let(:md_dir1) { make_test_dir(name: 'metadata1') }
      let(:path_dir1) { make_test_dir(name: 'path1') }
      after do
        FileUtils.rm_rf([md_dir1, path_dir1])
      end
      
      let(:file_selector) { build(:file_selector,
          storage_locations: ['loc1'],
          app_config: app_config) }
  
      let(:config) { ConfigBuilder.new
          .with_service(name: 'serv1')
          .with_location(name: 'loc1', path: path_dir1, md_path: md_dir1)
          .map_services(['loc1'], ['serv1'])
          .get }
      let(:app_config) { build(:application_config_manager, config: config) }
      
      let(:locator) { Longleaf::ServiceCandidateLocator.new(app_config) }
      
      it 'returns a ServiceCandidateFilesystemIterator' do
        expect(locator.candidate_iterator(file_selector, 'preserve')).to be_a(Longleaf::ServiceCandidateFilesystemIterator)
      end
    end
  end
end