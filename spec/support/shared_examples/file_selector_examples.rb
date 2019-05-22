RSpec.shared_examples 'file_selector.initialize' do |class_sym|
  describe '.initialize' do
    context 'no file paths or storage locations' do
      it {
        expect { build(class_sym, file_paths: nil, storage_locations: nil, app_config: app_config) }.to \
          raise_error(ArgumentError)
      }
    end

    context 'with empty file paths' do
      it {
        expect { build(class_sym, file_paths: [], storage_locations: nil, app_config: app_config) }.to \
          raise_error(ArgumentError)
      }
    end

    context 'both file paths and storage locations' do
      it {
        expect {
          build(class_sym,
     file_paths: [File.join(path_dir1, 'file')],
     storage_locations: ['loc1'],
     app_config: app_config)
        } .to raise_error(ArgumentError)
      }
    end

    context 'invalid storage location name' do
      it {
        expect {
          build(class_sym,
     storage_locations: ['foo'],
     app_config: app_config)
        } .to raise_error(Longleaf::StorageLocationUnavailableError)
      }
    end

    context 'valid storage location' do
      it {
        expect(build(class_sym,
        storage_locations: ['loc1'],
        app_config: app_config)).to be_a Longleaf::FileSelector
      }
    end

    context 'valid file path' do
      it {
        expect(build(class_sym,
        file_paths: [File.join(path_dir1, 'file')],
        app_config: app_config)).to be_a Longleaf::FileSelector
      }
    end
  end
end

RSpec.shared_examples 'file_selector.storage_locations' do |class_sym|
  describe '.storage_locations' do
    context 'with valid storage locations' do
      let(:selector) {
        build(class_sym,
              storage_locations: ['loc1', 'loc2'],
              app_config: app_config)
      }
      it { expect(selector.storage_locations).to contain_exactly('loc1', 'loc2') }
    end

    context 'with one file path' do
      let(:selector) {
        build(class_sym,
              file_paths: [File.join(path_dir1, 'file')],
              app_config: app_config)
      }
      it { expect(selector.storage_locations).to contain_exactly('loc1') }
    end

    context 'with multiple file paths' do
      let(:selector) {
        build(class_sym,
              file_paths: [File.join(path_dir1, 'file1'), File.join(path_dir1, 'file2')],
              app_config: app_config)
      }
      it { expect(selector.storage_locations).to contain_exactly('loc1') }
    end

    context 'with file paths in multiple locations' do
      let(:selector) {
        build(class_sym,
              file_paths: [File.join(path_dir1, 'file1'), File.join(path_dir2, 'other')],
              app_config: app_config)
      }
      it { expect(selector.storage_locations).to contain_exactly('loc1', 'loc2') }
    end

    context 'with file paths not in storage location' do
      let(:path_dir3) { make_test_dir() }
      after do
        FileUtils.rmdir([path_dir3])
      end

      let(:selector) {
        build(class_sym,
              file_paths: [File.join(path_dir3, 'file')],
              app_config: app_config)
      }
      it { expect(selector.storage_locations).to contain_exactly() }
    end
  end
end

RSpec.shared_examples 'file_selector.target_paths' do |class_sym|
  describe '.target_paths' do
    context 'from file paths' do
      let(:dir_path) { make_test_dir(parent: path_dir1, name: 'nested') }
      let(:selector) {
        build(class_sym,
              file_paths: [dir_path],
              app_config: app_config)
      }

      it 'returns storage location path' do
        expect(selector.target_paths).to contain_exactly(dir_path + '/')
      end
    end

    context 'from storage location' do
      let(:selector) {
        build(class_sym,
              storage_locations: ['loc1'],
              app_config: app_config)
      }

      it 'returns storage location path' do
        expect(selector.target_paths).to contain_exactly(path_dir1 + '/')
      end
    end

    context 'from relative file paths' do
      let(:dir_path) { make_test_dir(parent: path_dir1, name: 'nested') }
      let(:relative_path) { Pathname.new(dir_path).relative_path_from(Pathname.new(Dir.pwd)) }
      let(:selector) {
        build(class_sym,
              file_paths: [relative_path],
              app_config: app_config)
      }

      it 'returns absolute path to selected directory' do
        expect(selector.target_paths).to contain_exactly(dir_path + '/')
      end
    end
  end
end
