require 'longleaf/errors'
require 'longleaf/models/metadata_record'
require 'longleaf/services/metadata_deserializer'
require 'longleaf/services/metadata_serializer'
require 'time'

# Event to register a file with longleaf
module Longleaf
  class RegisterEvent
    # @param file_rec [FileRecord] file record
    # @param app_manager [ApplicationConfigManager] the application configuration
    # @param force [boolean] if true, then already registered files will be re-registered
    def initialize(file_rec:, app_manager:, force: false)
      raise ArgumentError.new('Must provide a file_rec parameter') if file_rec.nil?
      raise ArgumentError.new('Parameter file_rec must be a FileRecord') \
          unless file_rec.is_a?(FileRecord)
      raise ArgumentError.new('Must provide an ApplicationConfigManager') if app_manager.nil?
      raise ArgumentError.new('Parameter app_manager must be an ApplicationConfigManager') \
          unless app_manager.is_a?(ApplicationConfigManager)
      
      @app_manager = app_manager
      @file_rec = file_rec
      @force = force
    end
    
    # Perform a registration event on the given file
    # @raises RegistrationError if a file cannot be registered 
    def perform
      metadata_exists = File.file?(@file_rec.metadata_path)
      # If the file's metadata exists, only need to register it if the force flag is provided
      if metadata_exists && !@force
        raise RegistrationError.new("Unable to register '#{@file_rec.path}', it is already registered.")
      end
      
      # create metadata record
      md_rec = MetadataRecord.new(registered: Time.now.utc.iso8601)
      @file_rec.metadata_record = md_rec
      
      # retain significant details from former record
      if metadata_exists
        retain_existing_properties
      end
      
      populate_file_properties
      
      populate_services
      
      # persist the metadata out to file
      MetadataSerializer::write(metadata: md_rec, file_path: @file_rec.metadata_path)
    end
    
    private
    def populate_file_properties
      md_rec = @file_rec.metadata_record
      
      # Set file propeties
      md_rec.last_modified = File.mtime(@file_rec.path).utc.iso8601
      md_rec.file_size = File.size(@file_rec.path)
    end
    
    def populate_services
      md_rec = @file_rec.metadata_record
      
      service_manager = @app_manager.service_manager
      definitions = service_manager.list_service_definitions(location: @file_rec.storage_location.name)
      
      # Add service section
      definitions.each do |serv_def|
        serv_name = serv_def.name
        md_rec.add_service(serv_name)
      end
    end
    
    def retain_existing_properties
      md_rec = @file_rec.metadata_record
      
      # retains custom properties, stale-replicas flag
      old_md = MetadataDeserializer.deserialize(file_path: @file_rec.metadata_path)
      old_md.properties.each { |name, value| md_rec.properties[name] = value }
      old_md.list_services.each do |serv_name|
        serv_rec = old_md.service(serv_name)
        
        stale_replicas = serv_rec.stale_replicas
        if stale_replicas
          new_service = md_rec.service(serv_name)
          new_service.stale_replicas = stale_replicas unless new_service.nil?
        end
      end
    end
  end
end