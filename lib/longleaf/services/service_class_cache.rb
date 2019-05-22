require 'pathname'

module Longleaf
  # Cache for loading and retrieving preservation service classes
  class ServiceClassCache
    STD_PRESERVATION_SERVICE_PATH = 'longleaf/preservation_services/'

    def initialize(app_manager)
      @app_manager = app_manager
      # Cache storing per service definition instances of service classes
      @service_instance_cache = Hash.new
      # Cache storing per script path class of service
      @class_cache = Hash.new
    end

    # Returns an instance of the preversation service defined for the provided service definition,
    # based on the work_script and work_class properties provided.
    #
    # @param service_def [ServiceDefinition] definition of service to instantiate
    # @return [PreservationService] Instance of the preservation service class for the definition.
    def service_instance(service_def)
      service_name = service_def.name
      # Return the cached instance of the service
      if @service_instance_cache.key?(service_name)
        return @service_instance_cache[service_name]
      end

      clazz = service_class(service_def)
      # Cache and return the class instance
      @service_instance_cache[service_name] = clazz.new(service_def, @app_manager)
    end

    # Load and return the PreservationService class assigned to the provided service definition,
    # based on the work_script and work_class properties provided.
    #
    # @param service_def [ServiceDefinition] definition of service to retrieve class for
    # @return [Class] class of work_script
    def service_class(service_def)
      service_name = service_def.name
      work_script = service_def.work_script

      if work_script.include?('/')
        expanded_path = Pathname.new(work_script).expand_path.to_s
        if !from_permitted_path?(expanded_path)
          raise ConfigurationError.new("Unable to load work_script for service #{service_name}, #{work_script} is not in a known library path.")
        end

        last_slash_index = work_script.rindex('/')
        script_path = work_script[0..last_slash_index]
        script_name = work_script[(last_slash_index + 1)..-1]
      else
        script_path = STD_PRESERVATION_SERVICE_PATH
        script_name = work_script
      end

      # Strip off the extension
      script_name.sub!('.rb', '')

      require_path = File.join(script_path, script_name)
      # Return the cached Class if this path has been encountered before
      if @class_cache.key?(require_path)
        return @class_cache[require_path]
      end

      # Load the script
      begin
        require require_path
      rescue LoadError => e
        raise ConfigurationError.new("Failed to load work_script '#{script_name}' for service #{service_name}")
      end

      # Generate the class name, either configured or from file naming convention if possible
      if service_def.work_class
        class_name = service_def.work_class
      else
        class_name = script_name.split('_').map(&:capitalize).join
        # Assume the longleaf module for classes in the standard path
        class_name = 'Longleaf::' + class_name if script_path == STD_PRESERVATION_SERVICE_PATH
      end

      begin
        class_constant = constantize(class_name)
        # cache the class for this work_script and return it
        @class_cache[require_path] = class_constant
      rescue NameError
        raise ConfigurationError.new("Failed to load work_script '#{script_name}' for service #{service_name}, class name #{class_name} was not found.")
      end
    end

    private
    # Borrowed from sidekiq implementation
    def constantize(str)
      names = str.split('::')
      names.shift if names.empty? || names.first.empty?

      names.inject(Object) do |constant, name|
        # the false flag limits search for name to under the constant namespace
        #   which mimics Rails' behaviour
        constant.const_defined?(name, false) ? constant.const_get(name, false) : constant.const_missing(name)
      end
    end

    def from_permitted_path?(script_path)
      $LOAD_PATH.each do |lib_path|
        if script_path.start_with?(lib_path)
          return true
        end
      end
      false
    end
  end
end
