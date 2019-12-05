require 'pathname'
require 'longleaf/errors'

module Longleaf
  # Validates the configuration of a filesystem based location
  class FilesystemLocationValidator

    def self.validate(p_validator, name, path_prop, section_name, path)
      base_msg = "Storage location '#{name}' specifies invalid #{section_name} '#{path_prop}' property: "
      p_validator.assert(base_msg + 'Path must not be empty', !path.nil? && !path.to_s.strip.empty?)
      p_validator.assert(base_msg + 'Path must not contain any relative modifiers (/..)', !path.include?('/..'))
      p_validator.assert(base_msg + 'Path must be absolute', Pathname.new(path).absolute?)
      p_validator.assert(base_msg + 'Path does not exist', Dir.exist?(path))
    end
  end
end
