require 'tempfile'
require 'tmpdir'

module Longleaf
  module FileHelpers
    def make_test_dir(parent: nil, name: nil)
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
      if dir.nil?
        file = Tempfile.create(name)
        file << content
        file.close
        return file.path
      else
        path = File.join(dir, name)
        File.open(path, 'w') { |f| f.write(content) }
        path
      end
    end
  end
end