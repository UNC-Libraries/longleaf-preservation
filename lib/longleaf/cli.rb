require 'thor'
require 'yaml'
require 'longleaf/logging'
require 'longleaf/errors'
require 'longleaf/version'
require 'longleaf/commands/deregister_command'
require 'longleaf/commands/validate_config_command'
require 'longleaf/commands/validate_metadata_command'
require 'longleaf/commands/register_command'
require 'longleaf/commands/reindex_command'
require 'longleaf/commands/preserve_command'
require 'longleaf/candidates/file_selector'
require 'longleaf/candidates/registered_file_selector'

module Longleaf
  # Main commandline interface setup for Longleaf using Thor.
  class CLI < Thor
    include Longleaf::Logging

    # Register a shared method option in a shared option group
    def self.add_shared_option(name, group, options = {})
      @shared_groups = {} if @shared_groups.nil?
      @shared_groups[group] = {} if @shared_groups[group].nil?
      @shared_groups[group][name] = options
    end

    # Add all of the shared options in the specified group as method options
    def self.shared_options_group(group_name)
      @shared_groups[group_name].each do |opt_name, opt|
        option opt_name, opt
      end
    end

    # Config options
    add_shared_option(
        :config, :common, {
              :aliases => "-c",
              :default => ENV['LONGLEAF_CFG'],
              :required => false,
              :desc => 'Path to the application configuration used for this command. By default, the value of the environment variable LONGLEAF_CFG is used. A config path is required for most commands.' })
    add_shared_option(
        :load_path, :common, {
              :aliases => "-I",
              :desc => 'Specify comma seperated directories to add to the $LOAD_PATH, which can be used to specify additional paths from which to load preservation services.' })

    # Logging options
    add_shared_option(
        :failure_only, :common, {
              :type => :boolean,
              :default => false,
              :desc => 'Only display failure messages to STDOUT.' })
    add_shared_option(
        :log_level, :common, {
              :default => 'WARN',
              :desc => 'Level of logging to send to STDERR, following standard ruby Logger levels. This includes: DEBUG, INFO, WARN, ERROR, FATAL, UNKNOWN.' })
    add_shared_option(
        :log_format, :common, {
              :desc => 'Format to use for log information sent to STDERR. Can contain the following parameters, which must be wrapped in %{}: severity, datetime, progname, msg. Default is "%{severity} [%{datetime}]: %{msg}"' })
    add_shared_option(
        :log_datetime, :common, {
              :desc => 'Format to use for timestamps used in logging to STDERR, following strftime syntax.' })

    # File selection options
    add_shared_option(
        :file, :file_selection, {
              :aliases => "-f",
              :required => false,
              :desc => 'File or files to perform this operation on. If multiple files are provided, they must be comma separated.' })
    add_shared_option(
        :location, :file_selection, {
              :aliases => "-s",
              :required => false,
              :desc => 'Name or comma separated names of storage locations to perform this operation over.' })

    # Commands
    map %w[--version] => :__print_version
    desc "--version", "Prints the Longleaf version number."
    def __print_version
      puts "longleaf version #{Longleaf::VERSION}"
    end

    desc "register", "Register files with Longleaf"
    shared_options_group(:file_selection)
    method_option(:force,
        :type => :boolean,
        :default => false,
        :desc => 'Force the registration of already registered files.')
    method_option(:checksums,
        :desc => %q{Checksums for the submitted file. Each checksum must be prefaced with an algorithm prefix. Multiple checksums must be comma separated. If multiple files were submitted, they will be provided with the same checksums. For example:
          '--checksums "md5:d8e8fca2dc0f896fd7cb4cb0031ba249,sha1:4e1243bd22c66e76c2ba9eddc1f91394e57f9f83"'})
    shared_options_group(:common)
    # Register event command
    def register
      verify_config_provided(options)
      setup_logger(options)

      app_config_manager = load_application_config(options)

      file_selector = create_file_selector(options, app_config_manager)
      if options[:checksums]
        checksums = options[:checksums]
        # validate checksum list format, must a comma delimited list of prefix:checksums
        if /^[^:,]+:[^:,]+(,[^:,]+:[^:,]+)*$/.match(checksums)
          # convert checksum list into hash with prefix as key
          checksums = Hash[*checksums.split(/\s*[:,]\s*/)]
        else
          logger.failure("Invalid checksums parameter format, see `longleaf help <command>` for more information")
          exit 1
        end
      end

      command = RegisterCommand.new(app_config_manager)
      exit command.execute(file_selector: file_selector, force: options[:force], checksums: checksums)
    end

    desc "deregister", "Deregister files with Longleaf"
    shared_options_group(:file_selection)
    method_option(:force,
        :type => :boolean,
        :default => false,
        :desc => 'Force the deregistration of already deregistered files.')
    shared_options_group(:common)
    # Deregister event command
    def deregister
      verify_config_provided(options)
      setup_logger(options)

      app_config_manager = load_application_config(options)
      file_selector = create_registered_selector(options, app_config_manager)

      command = DeregisterCommand.new(app_config_manager)
      exit command.execute(file_selector: file_selector, force: options[:force])
    end

    desc "preserve", "Perform preservation services on files with Longleaf"
    shared_options_group(:file_selection)
    method_option(:force,
        :type => :boolean,
        :default => false,
        :desc => 'Force the execution of preservation services, disregarding scheduling information.')
    shared_options_group(:common)
    def preserve
      verify_config_provided(options)
      setup_logger(options)

      extend_load_path(options[:load_path])
      app_config_manager = load_application_config(options)
      file_selector = create_registered_selector(options, app_config_manager)

      command = PreserveCommand.new(app_config_manager)
      exit command.execute(file_selector: file_selector, force: options[:force])
    end

    desc "validate_config", "Validate an application configuration file, provided using --config."
    shared_options_group(:common)
    # Application configuration validation command
    def validate_config
      verify_config_provided(options)
      setup_logger(options)
      extend_load_path(options[:load_path])

      exit Longleaf::ValidateConfigCommand.new(options[:config]).execute
    end

    desc "validate_metadata", "Validate metadata files."
    shared_options_group(:file_selection)
    shared_options_group(:common)
    # File metadata validation command
    def validate_metadata
      verify_config_provided(options)
      setup_logger(options)

      app_config_manager = load_application_config(options)
      file_selector = create_registered_selector(options, app_config_manager)

      exit Longleaf::ValidateMetadataCommand.new(app_config_manager).execute(file_selector: file_selector)
    end

    desc "setup_index", "Sets up the structure of the metadata index, if one is configured using the system configuration file provided using the --system_config option. Some index types may require additional steps to be taken by an administrator before hand, such as creating users and databases."
    shared_options_group(:common)
    def setup_index
      verify_config_provided(options)
      setup_logger(options)

      app_config_manager = load_application_config(options)

      if app_config_manager.index_manager.using_index?
        app_config_manager.index_manager.setup_index
        logger.success("Setup of index complete")
        exit 0
      else
        logger.failure("No index configured, unable to perform setup.")
        exit 1
      end
    end

    desc "reindex", "Perform a full reindex of file metadata stored within the configured storage locations."
    method_option(:if_stale,
        :type => :boolean,
        :default => false,
        :desc => 'Only perform the reindex if the index is known to be stale, generally after an config file change.')
    shared_options_group(:common)
    def reindex
      verify_config_provided(options)
      setup_logger(options)
      app_config_manager = load_application_config(options)

      exit Longleaf::ReindexCommand.new(app_config_manager).execute(only_if_stale: options[:if_stale])
    end

    no_commands do
      def setup_logger(options)
        initialize_logger(options[:failure_only],
            options[:log_level],
            options[:log_format],
            options[:log_datetime])
      end

      def load_application_config(options)
        begin
          app_manager = ApplicationConfigDeserializer.deserialize(options[:config])
        rescue ConfigurationError => err
          logger.failure("Failed to load application configuration due to the following issue(s):\n#{err.message}")
          exit 1
        end
      end

      def verify_config_provided(options)
        if options[:config].nil? || options[:config].empty?
          raise "No value provided for required options '--config'"
        end
      end

      def create_file_selector(options, app_config_manager, selector_class: FileSelector)
        file_paths = options[:file]&.split(/\s*,\s*/)
        storage_locations = options[:location]&.split(/\s*,\s*/)

        begin
          selector_class.new(file_paths: file_paths, storage_locations: storage_locations, app_config: app_config_manager)
        rescue ArgumentError => e
          logger.failure(e.message)
          exit 1
        end
      end

      def create_registered_selector(options, app_config_manager)
        create_file_selector(options, app_config_manager, selector_class: RegisteredFileSelector)
      end

      def extend_load_path(load_paths)
        load_paths = load_paths&.split(/\s*,\s*/)
        load_paths&.each { |path| $LOAD_PATH.unshift(path) }
      end
    end
  end
end
