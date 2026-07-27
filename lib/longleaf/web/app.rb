require 'rack/utils'
require 'roda'
require 'longleaf/logging'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/web/job_registry'
require 'longleaf/web/controllers/register_controller'
require 'longleaf/web/controllers/deregister_controller'
require 'longleaf/web/controllers/preserve_controller'
require 'longleaf/web/controllers/jobs_controller'

module Longleaf
  module Web
    # Main Roda application for the Longleaf HTTP API.
    #
    # The application is configured at startup via the LONGLEAF_CFG environment
    # variable (or by passing a config path explicitly). All API routes delegate
    # to dedicated controller classes.
    class App < Roda
      plugin :json             # Auto-serialize Hash/Array return values to JSON
      plugin :json_parser, error_handler: proc { |r|
        r.halt(400, { 'content-type' => 'application/json' },
               [{ error: 'Invalid JSON in request body' }.to_json])
      }
      plugin :all_verbs        # Enable DELETE, PATCH, etc. in the routing tree
      plugin :halt             # r.halt for early exit with a status / body
      plugin :error_handler

      class << self
        attr_accessor :app_manager
        attr_accessor :job_registry

        def log_dir
          ENV.fetch('LONGLEAF_LOG_DIR', '/var/log/longleaf')
        end

        def app_config_path
          ENV['LONGLEAF_CFG']
        end

        def log_rotation_mode
          rotation_mode = ENV.fetch('LONGLEAF_LOG_ROTATION', '').strip.downcase
          return nil if rotation_mode.empty? || rotation_mode == 'off'

          rotation_mode
        end

        def configure_logging!
          failure_only = false
          log_level = ENV.fetch('LONGLEAF_LOG_LEVEL', 'INFO')
          log_format = ENV['LONGLEAF_LOG_FORMAT']
          datetime_format = nil

          if log_rotation_mode
            Longleaf::Logging.initialize_logger(
              failure_only,
              log_level,
              log_format,
              datetime_format,
              stdout_path: File.join(log_dir, 'longleaf.log'),
              stderr_path: File.join(log_dir, 'longleaf-error.log'),
              shift_age: log_rotation_mode
            )
          else
            Longleaf::Logging.initialize_logger(failure_only, log_level, log_format, datetime_format)
          end
        end

        def load_app_manager
          ApplicationConfigDeserializer.deserialize(app_config_path) unless app_config_path.nil?
        rescue Longleaf::ConfigurationError => e
          Longleaf::Logging.logger.warn("Failed to load Longleaf application configuration: #{e.message}")
          nil
        end
      end

      # Initialise the application logger for the web context.
      #   LONGLEAF_LOG_LEVEL     - Ruby Logger level string (default: INFO)
      #   LONGLEAF_LOG_FORMAT    - optional log format string (see RedirectingLogger)
      #   LONGLEAF_LOG_ROTATION  - set to 'daily' to enable file-backed rotation
      #   LONGLEAF_LOG_DIR       - directory used for rotated web log files
      configure_logging!

      @app_manager = load_app_manager

      @job_registry = JobRegistry.new

      error do |e|
        Longleaf::Logging.logger.error("[#{e.class}]: #{e.message}\n#{e.backtrace.first(10).join("\n")}")
        response.status = 500
        { error: e.message }
      end

      route do |r|
        # All endpoints are nested under /api
        r.on 'api' do
          # Enforce API key authentication when LONGLEAF_API_KEYS is configured.
          # Clients must supply a valid key in the X-Api-Key request header.
          # When the variable is absent or empty all requests are allowed through.
          #   LONGLEAF_API_KEYS  - comma-separated list of accepted API keys
          api_keys = ENV.fetch('LONGLEAF_API_KEYS', '').split(',').map(&:strip).reject(&:empty?)
          unless api_keys.empty? || api_keys.any? { |key| Rack::Utils.secure_compare(key, r.env['HTTP_X_API_KEY'].to_s) }
            r.halt(401, { error: 'Unauthorized' })
          end

          # POST /api/register
          r.on 'register' do
            r.post do
              Controllers::RegisterController.new(self.class.app_manager).handle(r)
            end
          end

          # POST /api/deregister
          r.on 'deregister' do
            r.post do
              Controllers::DeregisterController.new(self.class.app_manager).handle(r)
            end
          end

          # POST /api/preserve
          r.on 'preserve' do
            r.post do
              Controllers::PreserveController.new(self.class.app_manager, self.class.job_registry).handle(r)
            end
          end

          # GET /api/jobs        - list all jobs
          # GET /api/jobs/:id   - get a single job by id
          r.on 'jobs' do
            r.on String do |job_id|
              r.get do
                Controllers::JobsController.new(self.class.job_registry).handle(r, job_id)
              end
            end
            r.get do
              Controllers::JobsController.new(self.class.job_registry).list(r)
            end
          end
        end
      end
    end
  end
end
