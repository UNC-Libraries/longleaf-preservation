require_relative '../models/app_fields'
require 'yaml'

module Longleaf
  # Test helper for constructing application configuration hashes
  class ConfigBuilder
    AF = Longleaf::AppFields
    
    attr_accessor :config
  
    def initialize
      @config = Hash.new
    end
  
    # Add a root 'locations' field to the config
    # @param locations [Hash] value for the locations fields. Default is {}
    # @return this builder
    def with_locations(locations = Hash.new)
      @config[AF::LOCATIONS] = locations
      self
    end
  
    # Add a 'location' to the config
    # @param name [String] name of the location
    # @param path [String] value for the 'path' field
    # @param md_path [String] value for the 'metadata_path' field
    # @return this builder
    def with_location(name:, path: '/file/path/', md_path: '/metadata/path/')
      location = {}
      @config[AF::LOCATIONS][name] = location
      location[AF::LOCATION_PATH] = path unless path.nil?
      location[AF::METADATA_PATH] = md_path unless md_path.nil?
      self
    end
    
    # @return the constructed configuration
    def get
      @config
    end
    
    def write_to_yaml_file
      Tempfile.open('config') do |f|
        f.write(@config.to_yaml)
        return f.path
      end
    end
  end
end