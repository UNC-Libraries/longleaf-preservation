require 'pathname'
require 'longleaf/errors'

module Longleaf
  # Validates the configuration of an OCFL filesystem storage location.
  # In addition to the basic filesystem checks, verifies that the path contains
  # an OCFL namaste file (e.g. "0=ocfl_1.1" or "0=ocfl_1.0") at the storage root.
  class OcflLocationValidator
    NAMASTE_PATTERN = /\A0=ocfl_\d+\.\d+\z/

    def self.validate(p_validator, name, path_prop, section_name, path)
      base_msg = "Storage location '#{name}' specifies invalid #{section_name} '#{path_prop}' property: "
      p_validator.assert(base_msg + 'Path must not be empty', !path.nil? && !path.to_s.strip.empty?)
      return unless path && !path.to_s.strip.empty?

      p_validator.assert(base_msg + 'Path must not contain any relative modifiers (/..)', !path.include?('/..'))
      p_validator.assert(base_msg + 'Path must be absolute', Pathname.new(path).absolute?)
      p_validator.assert(base_msg + 'Path does not exist', Dir.exist?(path))
      return unless Dir.exist?(path)

      namaste = Dir.entries(path).find { |entry| entry =~ NAMASTE_PATTERN }
      p_validator.assert(base_msg + 'Path does not contain an OCFL namaste file (e.g. "0=ocfl_1.1")', !namaste.nil?)
    end
  end
end
