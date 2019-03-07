require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/specs/file_helpers'
require 'longleaf/specs/config_builder'
require 'longleaf/helpers/service_date_helper'
require 'longleaf/services/metadata_serializer'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/services/application_config_deserializer'
require 'tempfile'
require 'yaml'
require 'fileutils'

describe 'preserve', :type => :aruba do
  include Longleaf::FileHelpers
  ConfigBuilder ||= Longleaf::ConfigBuilder
  
  let(:path_dir) { Dir.mktmpdir('path') }
  let(:md_dir) { Dir.mktmpdir('metadata') }
  let(:lib_dir) { make_test_dir(name: 'lib_dir') }
  
  after do
    FileUtils.rm_rf([md_dir, path_dir, lib_dir])
    $LOAD_PATH.delete(lib_dir)
  end
  
  context 'config path does not exist' do
    before do
      config_file = Tempfile.new('config')
      config_path = config_file.path
      config_file.delete

      run_simple("longleaf preserve -c #{config_path} -f '/path/to/file'", fail_on_error: false)
    end

    it 'outputs error loading configuration' do
      expect(last_command_started).to have_output(/Failed to load application configuration/)
      expect(last_command_started).to have_output(/file .* does not exist/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'with one service configured' do
    let!(:work_script_file) { create_work_class(lib_dir, 'PresService', 'pres_service.rb') }

    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: work_script_file, frequency: '1 hour')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file }
    let(:file_path) { create_test_file(dir: path_dir) }

    context 'no file path or storage location' do
      before do
        run_simple("longleaf preserve -c #{config_path}", fail_on_error: false)
      end

      it 'exits with failure' do
        expect(last_command_started).to have_output(/Must provide either file paths or storage locations/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'both file path and storage location' do
      before do
        run_simple("longleaf preserve -c #{config_path} -s loc1 -f #{file_path}", fail_on_error: false)
      end

      it 'exits with failure' do
        expect(last_command_started).to have_output(/Cannot provide both file paths and storage locations/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'invalid storage location' do
      before do
        run_simple("longleaf preserve -c #{config_path} -s nope", fail_on_error: false)
      end

      it 'exits with failure' do
        expect(last_command_started).to have_output(/Cannot select unknown storage location/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'file not from a valid storage location' do
      before do
        test_file = Tempfile.new('not_in_loc')
        out_of_location = test_file.path
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{out_of_location}", fail_on_error: false)
      end

      it 'fails with message indicating unknown storage location' do
        expect(last_command_started).to have_output(/FAILURE preserve: .+ not from a known storage location./)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'specifying unregistered file' do
      before do
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
      end

      it 'completes with no output' do
        expect(last_command_started).to_not have_output
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'specifying one file' do
      before do
        run_simple("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)
      end

      context 'service has not run before' do
        before do
          run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
        end
        
        it 'successfully verifies file' do
          expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path}/)
          expect(last_command_started).to have_exit_status(0)
        end
      end

      context 'does not need to run again' do
        before do
          update_timestamp(file_path, config_path, 'serv1')
          run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
        end

        it 'completes without any output' do
          expect(last_command_started).to_not have_output
          expect(last_command_started).to have_exit_status(0)
        end
      end

      context 'does not need to run again, force flag provided' do
        before do
          update_timestamp(file_path, config_path, 'serv1')
          run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path} --force", fail_on_error: false)
        end

        it 'successfully verifies file' do
          expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path}/)
          expect(last_command_started).to have_exit_status(0)
        end
      end

      context 'needs to run again' do
        before do
          # Change the last run timestamp to a while ago
          update_timestamp(file_path, config_path, 'serv1', timestamp: Time.new(2000))

          run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
        end

        it 'successfully verifies file' do
          expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path}/)
          expect(last_command_started).to have_exit_status(0)
        end
      end
    end
  end

  context 'with failing service configured' do
    let!(:fail_script) { create_work_class(lib_dir, 'PresService', 'pres_service.rb',
        perform: "raise Longleaf::PreservationServiceError.new") }

    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: fail_script, frequency: '1 year')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file }
    let(:file_path) { create_test_file(dir: path_dir) }

    before do
      run_simple("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)
      run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
    end

    it 'fails to verify file' do
      expect(last_command_started).to have_output(/FAILURE preserve\[serv1\] #{file_path}/)
      expect(last_command_started).to have_exit_status(1)
    end
  end

  context 'storage location with multiple files' do
    let!(:work_script_file) { create_work_class(lib_dir, 'PresService', 'pres_service.rb') }

    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: work_script_file, frequency: '1 hour')
        .map_services('loc1', 'serv1')
        .write_to_yaml_file }
    let(:file_path1) { create_test_file(dir: path_dir, name: "file1") }
    let(:nested_dir) { make_test_dir(parent: path_dir) }
    let(:file_path2) { create_test_file(dir: nested_dir, name: "file2") }
    let(:file_path3) { create_test_file(dir: path_dir, name: "file3") }

    before do
      run_simple("longleaf register -c #{config_path} -f #{file_path1},#{file_path2},#{file_path3}", fail_on_error: false)
    end

    context 'all files need service' do
      before do
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -s loc1", fail_on_error: false)
      end

      it 'successfully verifies file' do
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path1}/)
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path2}/)
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path3}/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'one file fails service' do
      let!(:work_script_file) { create_work_class(lib_dir, 'PresService', 'pres_service.rb',
          perform: "raise Longleaf::PreservationServiceError.new('Bad') if file_rec.path == '#{file_path2}'") }

      before do
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -s loc1", fail_on_error: false)
      end

      it 'successfully verifies two files, fails one' do
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path1}/)
        expect(last_command_started).to have_output(/FAILURE preserve\[serv1\] #{file_path2}/)
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path3}/)
        expect(last_command_started).to have_exit_status(2)
      end
    end

    context 'all files fails service' do
      let!(:work_script_file) { create_work_class(lib_dir, 'PresService', 'pres_service.rb',
          perform: "raise Longleaf::PreservationServiceError.new('Bad')") }

      before do
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -s loc1", fail_on_error: false)
      end

      it 'all files fail for the service' do
        expect(last_command_started).to have_output(/FAILURE preserve\[serv1\] #{file_path1}/)
        expect(last_command_started).to have_output(/FAILURE preserve\[serv1\] #{file_path2}/)
        expect(last_command_started).to have_output(/FAILURE preserve\[serv1\] #{file_path3}/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'one file does not need service' do
      before do
        # Set timestamp for service on the second file so that it does not need to be run again
        update_timestamp(file_path2, config_path, 'serv1')

        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -s loc1", fail_on_error: false)
      end

      it 'successfully verifies two files, skips one' do
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path1}/)
        expect(last_command_started).to_not have_output(/#{file_path2}/)
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path3}/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'no files need service' do
      before do
        # Set timestamp for service on all files so that they do not need to run
        update_timestamp(file_path1, config_path, 'serv1')
        update_timestamp(file_path2, config_path, 'serv1')
        update_timestamp(file_path3, config_path, 'serv1')

        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -s loc1", fail_on_error: false)
      end

      it 'skips all files' do
        expect(last_command_started).to_not have_output
        expect(last_command_started).to have_exit_status(0)
      end
    end
  end

  context 'with multiple services configured' do
    let!(:work_script_file1) { create_work_class(lib_dir, 'PresService1', 'pres_service1.rb') }
    let!(:work_script_file2) { create_work_class(lib_dir, 'PresService2', 'pres_service2.rb') }
    let!(:work_script_file3) { create_work_class(lib_dir, 'PresService3', 'pres_service3.rb') }

    let!(:config_path) { ConfigBuilder.new
        .with_location(name: 'loc1', path: path_dir, md_path: md_dir)
        .with_service(name: 'serv1', work_script: work_script_file1, frequency: '1 hour')
        .with_service(name: 'serv2', work_script: work_script_file2, frequency: '1 hour')
        .with_service(name: 'serv3', work_script: work_script_file3, frequency: '1 hour')
        .map_services('loc1', ['serv1', 'serv2', 'serv3'])
        .write_to_yaml_file }
    let(:file_path) { create_test_file(dir: path_dir) }

    before do
      run_simple("longleaf register -c #{config_path} -f #{file_path}", fail_on_error: false)
    end

    context 'all services needed' do
      before do
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
      end

      it 'reports that all services succeeded' do
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path}/)
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv2\] #{file_path}/)
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv3\] #{file_path}/)
        expect(last_command_started).to have_exit_status(0)
      end
    end

    context 'service fails with expected error' do
      let!(:work_script_file2) { create_work_class(lib_dir, 'PresService2', 'pres_service2.rb',
          perform: "raise Longleaf::PreservationServiceError.new('Bad')") }

      before do
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
      end

      it 'reports that one service failed' do
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path}/)
        expect(last_command_started).to have_output(/FAILURE preserve\[serv2\] #{file_path}/)
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv3\] #{file_path}/)
        expect(last_command_started).to have_exit_status(2)
      end
    end

    context 'service fails with unexpected error' do
      let!(:work_script_file2) { create_work_class(lib_dir, 'PresService2', 'pres_service2.rb',
          perform: "raise StandardError.new('Really Bad')") }

      before do
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
      end

      it 'reports that one service succeeded, one failed, and one was skipped' do
        expect(last_command_started).to have_output(/SUCCESS preserve\[serv1\] #{file_path}/)
        expect(last_command_started).to have_output(/FAILURE preserve\[serv2\] #{file_path}/)
        expect(last_command_started).to_not have_output(/serv3/)
        expect(last_command_started).to have_exit_status(2)
      end
    end

    context 'all services fail' do
      let!(:work_script_file1) { create_work_class(lib_dir, 'PresService1', 'pres_service1.rb',
          perform: "raise Longleaf::PreservationServiceError.new('Bad1')") }
      let!(:work_script_file2) { create_work_class(lib_dir, 'PresService2', 'pres_service2.rb',
          perform: "raise Longleaf::PreservationServiceError.new('Bad2')") }
      let!(:work_script_file3) { create_work_class(lib_dir, 'PresService3', 'pres_service3.rb',
          perform: "raise Longleaf::PreservationServiceError.new('Bad3')") }

      before do
        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path}", fail_on_error: false)
      end

      it 'reports that all services failed' do
        expect(last_command_started).to have_output(/FAILURE preserve\[serv1\] #{file_path}/)
        expect(last_command_started).to have_output(/FAILURE preserve\[serv2\] #{file_path}/)
        expect(last_command_started).to have_output(/FAILURE preserve\[serv3\] #{file_path}/)
        expect(last_command_started).to have_exit_status(1)
      end
    end

    context 'no services needed' do
      before do
        # Set all the timestamps to indicate having run recently
        update_timestamp(file_path, config_path, 'serv1')
        update_timestamp(file_path, config_path, 'serv2')
        update_timestamp(file_path, config_path, 'serv3')

        run_simple("longleaf preserve -c #{config_path} -I #{lib_dir} -f #{file_path} --log_level 'DEBUG'", fail_on_error: false)
      end

      it 'indicates that no services ran' do
        expect(last_command_started).to_not have_output
        expect(last_command_started).to have_exit_status(0)
      end
    end
  end
    
  def get_metadata_path(file_path, config_path)
    app_config = Longleaf::ApplicationConfigDeserializer.deserialize(config_path)
    location = app_config.location_manager.get_location_by_path(file_path)
    location.get_metadata_path_for(file_path)
  end
  
  def update_timestamp(file_path, config_path, service_name, timestamp: Time.now)
    md_path = get_metadata_path(file_path, config_path)
    md_rec = Longleaf::MetadataDeserializer.deserialize(file_path: md_path)
    md_rec.service(service_name).timestamp = Longleaf::ServiceDateHelper.formatted_timestamp(timestamp)
    Longleaf::MetadataSerializer.write(metadata: md_rec, file_path: md_path)
  end
end
  