require_relative '../models/app_fields'
require_relative '../models/service_fields'
require 'yaml'

# Test helper for constructing application configuration hashes
module Longleaf
  class ConfigBuilder
    AF = Longleaf::AppFields
    SF = Longleaf::ServiceFields
    
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
    
    # Add a root 'services' field to the config
    # @param services [Hash] value for the services field. Default is {}
    # @return this builder
    def with_services(services = Hash.new)
      @config[AF::SERVICES] = services
      self
    end
    
    # Add a 'service' to the config
    # @param name [String] name of the service
    # @param work_script [String] value for the 'work_script' field
    # @param frequency [String] value for the 'frequency' field
    # @param delay [String] value for the 'delay' field
    # @return this builder
    def with_service(name:, work_script: 'some_pres_service.rb', frequency: nil, delay: nil)
      service = {}
      @config[AF::SERVICES][name] = service
      service[SF::WORK_SCRIPT] = work_script
      service[SF::FREQUENCY] = frequency unless frequency.nil?
      service[SF::DELAY] = delay unless delay.nil?
      self
    end
    
    # @return the constructed configuration
    def get
      @config
    end
    
    # Writes the configuration from this builder into a temporary file
    # @return the file path of the config file
    def write_to_yaml_file
      Tempfile.open('config') do |f|
        f.write(@config.to_yaml)
        return f.path
      end
    end
  end
end