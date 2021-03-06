require 'longleaf/models/app_fields'
require 'longleaf/models/service_fields'
require 'yaml'

module Longleaf
  # Test helper for constructing application configuration hashes
  class ConfigBuilder
    AF ||= Longleaf::AppFields
    SF ||= Longleaf::ServiceFields

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
    def with_location(name:, path: '/file/path/', s_type: nil, md_path: '/metadata/path/', md_type: nil, md_digests: nil)
      @config[AF::LOCATIONS] = Hash.new unless @config.key?(AF::LOCATIONS)

      location = {}
      @config[AF::LOCATIONS][name] = location
      location[AF::LOCATION_PATH] = path unless path.nil?
      location[AF::STORAGE_TYPE] = s_type unless s_type.nil?

      if !md_path.nil?
        md_loc = { AF::LOCATION_PATH => md_path }
        location[AF::METADATA_CONFIG] = md_loc

        md_loc[AF::METADATA_DIGESTS] = md_digests unless md_digests.nil?
        md_loc[AF::STORAGE_TYPE] = md_type unless md_type.nil?
      end
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
    # @param work_class [String] value for the 'work_class' field
    # @param frequency [String] value for the 'frequency' field
    # @param delay [String] value for the 'delay' field
    # @param properties [Hash] hash of additional properties to include in the service
    # @return this builder
    def with_service(name:, work_script: 'some_pres_service.rb', work_class: nil,
         frequency: nil, delay: nil, properties: nil)
      @config[AF::SERVICES] = Hash.new unless @config.key?(AF::SERVICES)

      service = {}
      service[SF::WORK_SCRIPT] = work_script
      service[SF::WORK_CLASS] = work_class
      service[SF::FREQUENCY] = frequency unless frequency.nil?
      service[SF::DELAY] = delay unless delay.nil?
      service = service.merge(properties) unless properties.nil?
      @config[AF::SERVICES][name] = service
      self
    end

    # Adds a 'service_mappings' section to the config
    # @param mappings [Object] the mappings config
    # @return this builder
    def with_mappings(mappings = Hash.new)
      @config[AF::SERVICE_MAPPINGS] = mappings
      self
    end

    # Add a mapping from one or more services to one or more location
    # @param loc_names [Object] one or more location names. Can be a string or array.
    # @param service_names [Object] one or more service names. Can be a string or array.
    def map_services(loc_names, service_names)
      @config[AF::SERVICE_MAPPINGS] = Array.new unless @config.key?(AF::SERVICE_MAPPINGS)

      mapping = Hash.new
      mapping[AF::LOCATIONS] = loc_names unless loc_names.nil?
      mapping[AF::SERVICES] = service_names unless service_names.nil?
      @config[AF::SERVICE_MAPPINGS].push(mapping)
      self
    end

    # Add a system config section to the config
    def with_system(sys_config)
      @config[AF::SYSTEM] = sys_config
      self
    end

    # @return the constructed configuration
    def get
      @config
    end

    # Writes the configuration from this builder into a temporary file
    # @return the file path of the config file
    def write_to_yaml_file(dest_path = nil)
      if dest_path.nil?
        file = Tempfile.new('config')
        file.close
        dest_path = file.path
        # deleting temp file but reusing file name. This is to avoid premature garbage collection.
        file.unlink
      end
      File.open(dest_path, 'w') do |f|
        f.write(@config.to_yaml)
      end
      dest_path
    end
  end
end
