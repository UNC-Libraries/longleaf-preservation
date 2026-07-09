require 'spec_helper'
require 'rack/test'
require 'json'
require 'fileutils'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/commands/register_command'
require 'longleaf/candidates/file_selector'
require 'longleaf/candidates/physical_path_provider'
require 'longleaf/web/app'
require_relative '../support/shared_examples/api_key_auth_examples'

describe 'POST /api/preserve' do
  include Rack::Test::Methods
  include Longleaf::FileHelpers

  ConfigBuilder ||= Longleaf::ConfigBuilder

  def app
    Longleaf::Web::App
  end

  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir)   { Dir.mktmpdir('metadata') }

  after do
    FileUtils.remove_dir(md_dir)
    FileUtils.remove_dir(path_dir)
    Longleaf::Web::App.app_manager = nil
  end

  def load_config(config_path)
    manager = Longleaf::ApplicationConfigDeserializer.deserialize(config_path)
    Longleaf::Web::App.app_manager = manager
    manager
  end

  def register_files(*file_paths)
    physical_provider = Longleaf::PhysicalPathProvider.new
    selector = Longleaf::FileSelector.new(
      file_paths: file_paths,
      physical_provider: physical_provider,
      app_config: Longleaf::Web::App.app_manager
    )
    Longleaf::RegisterCommand.new(Longleaf::Web::App.app_manager)
      .execute(file_selector: selector, physical_provider: physical_provider)
  end

  def call_preserve(params = {})
    post '/api/preserve', params.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  def response_body
    JSON.parse(last_response.body)
  end

  # =========================================================================

  context 'API key authentication' do
    def make_request
      call_preserve(file: '/some/path')
    end

    it_behaves_like 'API key authentication'
  end

  # =========================================================================

  context 'when application configuration is not loaded' do
    before { Longleaf::Web::App.app_manager = nil }

    it 'returns 503' do
      call_preserve(file: '/some/path')
      expect(last_response.status).to eq 503
    end
  end

  # =========================================================================

  context 'with a valid application configuration' do
    let!(:config_path) do
      ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file
    end

    before { load_config(config_path) }

    context 'when no file selection parameter is provided' do
      it 'returns 400' do
        call_preserve
        expect(last_response.status).to eq 400
      end
    end

    context 'when an unsupported parameter is provided' do
      let!(:file_path) { create_test_file(dir: path_dir) }

      before { register_files(file_path) }

      it 'returns 400' do
        call_preserve(file: '/some/path', checksum: 'sha1:abc123')
        expect(last_response.status).to eq 400
        expect(response_body['error']).to include('checksum')
      end
    end

    context 'preserve a single registered file' do
      let!(:file_path) { create_test_file(dir: path_dir) }

      before { register_files(file_path) }

      it 'returns 202 with a job_id' do
        call_preserve(file: file_path)

        expect(last_response.status).to eq 202
        expect(response_body['job_id']).not_to be_nil
      end
    end

    context 'preserve all files in a storage location' do
      let!(:file_path)  { create_test_file(dir: path_dir) }
      let!(:file_path2) { create_test_file(dir: path_dir, name: 'loc_file2', content: 'other content') }

      before { register_files(file_path, file_path2) }

      it 'returns 202 with a job_id' do
        call_preserve(location: 'loc1')

        expect(last_response.status).to eq 202
        expect(response_body['job_id']).not_to be_nil
      end
    end

    context 'preserve files via from_list with inline body' do
      let!(:file_path)  { create_test_file(dir: path_dir) }
      let!(:file_path2) { create_test_file(dir: path_dir, name: 'list_file2', content: 'list content') }

      before { register_files(file_path, file_path2) }

      it 'returns 202 with a job_id' do
        call_preserve(from_list: '@-', body: "#{file_path}\n#{file_path2}")

        expect(last_response.status).to eq 202
        expect(response_body['job_id']).not_to be_nil
      end

      it 'returns 400 when from_list is "@-" but body is absent' do
        call_preserve(from_list: '@-')

        expect(last_response.status).to eq 400
        expect(response_body['error']).to include('body')
      end
    end
  end
end
