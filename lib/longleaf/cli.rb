require 'thor'
require 'yaml'
require 'longleaf/logging'
require 'longleaf/errors'
require 'longleaf/commands/validate_config_command'
require 'longleaf/commands/register_command'

module Longleaf
  class CLI < Thor
    include Longleaf::Logging
    
    class_option(:config, :aliases => "-c",
        :default => ENV['LONGLEAF_CFG'],
        :desc => 'Absolute path to the application configuration used for this command. By default, the value of the environment variable LONGLEAF_CFG is used.')
    # Logging/output options
    class_option(:failure_only,
        :type => :boolean,
        :default => false,
        :desc => 'Only display failure messages to STDOUT.')
    class_option(:log_level,
        :default => 'WARN',
        :desc => 'Level of logging to send to STDERR, following standard ruby Logger levels. This includes: DEBUG, INFO, WARN, ERROR, FATAL, UNKNOWN. Default is WARN.')
    class_option(:log_format,
        :desc => 'Format to use for log information sent to STDERR. Can contain the following parameters, which must be wrapped in %{}: severity, datetime, progname, msg. Default is "%{severity} [%{datetime}]: %{msg}"')
    class_option(:log_datetime,
        :desc => 'Format to use for timestamps used in logging to STDERR, following strftime syntax.')
    
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
    def register
      setup_logger(options)
      
      config_path = options[:config]
      file_paths = options[:file]&.split(/\s*,\s*/)
      if options[:checksums]
        checksums = options[:checksums]
        # validate checksum list format, must a comma delimited list of prefix:checksums
        if /^[^:,]+:[^:,]+(,[^:,]+:[^:,]+)*$/.match(checksums)
          # convert checksum list into hash with prefix as key
          checksums = Hash[*checksums.split(/\s*[:,]\s*/)]
        else
          logger.failure("Invalid checksums parameter format, see `longleaf help <command>` for more information")
          return
        end
      end
      
      command = Longleaf::RegisterCommand.new(config_path)
      command.execute(file_paths: file_paths, force: options[:force], checksums: checksums)
    end
    
    desc "validate_config [CONFIG_PATH]", "Validate an application configuration file"
    # Application configuration validation command
    def validate_config(config_path)
      setup_logger(options)
      
      Longleaf::ValidateConfigCommand.new(config_path).perform
    end
    
    no_commands do
      def setup_logger(options)
        initialize_logger(options[:failure_only],
            options[:log_level],
            options[:log_format],
            options[:log_datetime])
      end
    end
  end
end