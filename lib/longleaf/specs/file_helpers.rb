require 'tempfile'
require 'tmpdir'

module Longleaf
  # Test helper methods for creating test files
  module FileHelpers
    def make_test_dir(parent: nil, name: 'dir')
      FileHelpers.make_test_dir(parent: parent, name: name)
    end
    
    def self.make_test_dir(parent: nil, name: 'dir')
      if parent.nil?
        Dir.mktmpdir(name)
      else
        path = File.join(parent, name)
        Dir.mkdir(path)
        path
      end
    end
    
    def create_test_file(dir: nil, name: 'test_file', content: 'content')
      FileHelpers.create_test_file(dir: dir, name: name, content: content)
    end
    
    def self.create_test_file(dir: nil, name: 'test_file', content: 'content')
      file = Tempfile.create(name, dir)
      file << content
      file.close
      return file.path
    end
    
    def create_work_class(lib_dir, class_name, file_name, module_name = nil, is_applicable: true, init_body: "", perform: "")
      FileHelpers.create_work_class(lib_dir, class_name, file_name, module_name, is_applicable, init_body, perform)
    end
    
    def self.create_work_class(lib_dir, class_name, file_name, module_name, is_applicable, init_body, perform)
      class_contents = %Q(
        class #{class_name}
          def initialize(service_def, app_manager)
            #{init_body}
          end
          def perform(file_rec, event)
            #{perform}
          end
          def is_applicable?(event)
            #{is_applicable}
          end
        end
      )
      class_contents = "module #{module_name}\n#{class_contents}\nend" unless module_name.nil?
      create_test_file(dir: lib_dir, name: file_name, content: class_contents)
    end
  end
end