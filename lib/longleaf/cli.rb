require 'thor'
require 'yaml'
require 'longleaf/errors'
require 'longleaf/commands/validate_config_command'
require 'longleaf/commands/register_command'

module Longleaf
  class CLI < Thor
    class_option(:config, :aliases => "-c",
        :default => ENV['LONGLEAF_CFG'],
        :desc => 'Absolute path to the application configuration used for this command. By default, the value of the environment variable LONGLEAF_CFG is used.')
    
    desc "register", "Register files with Longleaf"
    method_option(:file, :aliases => "-f", 
        :required => true,
        :desc => 'File or files to register. Paths must be absolute. If multiple files are provided, they must be comma separated.')
    method_option(:force,
        :type => :boolean, 
        :default => false,
        :desc => 'Force the registration of already registered files.')
    method_option(:checksums,
        :desc => %q{Checksums for the submitted file. Each checksum must be prefaced with an algorithm prefix. Multiple checksums must be comma separated. If multiple files were submitted, they will be provided with the same checksums. For example: 
          '--checksums "md5:d8e8fca2dc0f896fd7cb4cb0031ba249,sha1:4e1243bd22c66e76c2ba9eddc1f91394e57f9f83"'})
    # Register event command
    def register()
      config_path = options[:config]
      file_paths = options[:file]&.split(/\s*,\s*/)
      if options[:checksums]
        checksums = options[:checksums]
        # validate checksum list format, must a comma delimited list of prefix:checksums
        if /^[^:,]+:[^:,]+(,[^:,]+:[^:,]+)*$/.match(checksums)
          # convert checksum list into hash with prefix as key
          checksums = Hash[*checksums.split(/\s*[:,]\s*/)]
        else
          puts "Invalid checksums parameter format, see `longleaf help <command>` for more information"
          return
        end
      end
      
      command = Longleaf::RegisterCommand.new(config_path)
      command.execute(file_paths: file_paths, force: options[:force], checksums: checksums)
    end
    
    desc "validate_config [CONFIG_PATH]", "Validate an application configuration file"
    # Application configuration validation command
    def validate_config(config_path)
      Longleaf::ValidateConfigCommand.new(config_path).perform
    end
  end
end