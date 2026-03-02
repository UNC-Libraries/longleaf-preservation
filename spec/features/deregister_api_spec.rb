require 'spec_helper'
require 'rack/test'
require 'json'
require 'fileutils'
require 'longleaf/specs/config_builder'
require 'longleaf/specs/file_helpers'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/services/metadata_serializer'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/commands/register_command'
require 'longleaf/candidates/file_selector'
require 'longleaf/candidates/physical_path_provider'
require 'longleaf/web/app'

describe 'DELETE /api/deregister' do
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

  def delete_deregister(params = {})
    delete '/api/deregister', params.to_json, 'CONTENT_TYPE' => 'application/json'
  end

  def response_body
    JSON.parse(last_response.body)
  end

  # --- metadata helpers ---

  def metadata_record_path(file_path)
    File.join(md_dir, File.basename(file_path) + Longleaf::MetadataSerializer::metadata_suffix)
  end

  def get_metadata_record(file_path)
    Longleaf::MetadataDeserializer.deserialize(file_path: metadata_record_path(file_path))
  end

  def file_deregistered?(file_path)
    path = metadata_record_path(file_path)
    return false unless File.exist?(path)
    get_metadata_record(file_path).deregistered?
  end

  # =========================================================================

  context 'when application configuration is not loaded' do
    before { Longleaf::Web::App.app_manager = nil }

    it 'returns 503' do
      delete_deregister(file: '/some/path')
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
        delete_deregister
        expect(last_response.status).to eq 400
      end
    end

    context 'when the file is not registered' do
      let!(:file_path) { create_test_file(dir: path_dir) }

      it 'returns 500' do
        delete_deregister(file: file_path)
        expect(last_response.status).to eq 500
      end
    end

    context 'when the file is not in a known storage location' do
      let!(:outside_file) { create_test_file }

      after { File.delete(outside_file) if File.exist?(outside_file) }

      it 'returns 500' do
        delete_deregister(file: outside_file)
        expect(last_response.status).to eq 500
      end
    end

    context 'deregister a single registered file' do
      let!(:file_path) { create_test_file(dir: path_dir) }

      before { register_files(file_path) }

      it 'returns 202 and marks the file as deregistered' do
        delete_deregister(file: file_path)

        expect(last_response.status).to eq 202
        expect(response_body['status']).to eq 'success'
        expect(file_deregistered?(file_path)).to be true
      end
    end

    context 'deregister multiple registered files' do
      let!(:file_path)  { create_test_file(dir: path_dir) }
      let!(:file_path2) { create_test_file(dir: path_dir, name: 'another_file', content: 'more content') }

      before { register_files(file_path, file_path2) }

      it 'returns 202 and marks both files as deregistered' do
        delete_deregister(file: "#{file_path},#{file_path2}")

        expect(last_response.status).to eq 202
        expect(file_deregistered?(file_path)).to be true
        expect(file_deregistered?(file_path2)).to be true
      end
    end

    context 'deregister an already-deregistered file' do
      let!(:file_path) { create_test_file(dir: path_dir) }

      before do
        register_files(file_path)
        delete_deregister(file: file_path)
      end

      it 'returns 500 on a second request without force' do
        delete_deregister(file: file_path)
        expect(last_response.status).to eq 500
      end

      it 'returns 202 on a second request with force: true' do
        delete_deregister(file: file_path, force: 'true')
        expect(last_response.status).to eq 202
        expect(file_deregistered?(file_path)).to be true
      end
    end

    context 'deregister all files in a storage location' do
      let!(:file_path)  { create_test_file(dir: path_dir) }
      let!(:file_path2) { create_test_file(dir: path_dir, name: 'loc_file2', content: 'other content') }

      before { register_files(file_path, file_path2) }

      it 'returns 202 and deregisters all files in the location' do
        delete_deregister(location: 'loc1')

        expect(last_response.status).to eq 202
        expect(file_deregistered?(file_path)).to be true
        expect(file_deregistered?(file_path2)).to be true
      end
    end

    context 'deregister a registered file that no longer exists on disk' do
      let!(:file_path) { create_test_file(dir: path_dir) }

      before do
        register_files(file_path)
        File.delete(file_path)
      end

      it 'returns 202 and marks the file as deregistered' do
        delete_deregister(file: file_path)

        expect(last_response.status).to eq 202
        expect(file_deregistered?(file_path)).to be true
      end
    end
  end
end
