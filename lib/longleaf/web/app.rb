require 'roda'
require 'longleaf/services/application_config_deserializer'
require 'longleaf/web/controllers/register_controller'
require 'longleaf/web/controllers/deregister_controller'

module Longleaf
  module Web
    # Main Roda application for the Longleaf HTTP API.
    #
    # The application is configured at startup via the LONGLEAF_CFG environment
    # variable (or by passing a config path explicitly). All API routes delegate
    # to dedicated controller classes.
    class App < Roda
      plugin :json             # Auto-serialize Hash/Array return values to JSON
      plugin :json_parser      # Parse incoming application/json request bodies
      plugin :all_verbs        # Enable DELETE, PATCH, etc. in the routing tree
      plugin :halt             # r.halt for early exit with a status / body
      plugin :error_handler

      # Load the application configuration once at startup. The path is taken
      # from the LONGLEAF_CFG environment variable, mirroring the CLI behaviour.
      APP_CONFIG_PATH = ENV['LONGLEAF_CFG']

      @app_manager = begin
        ApplicationConfigDeserializer.deserialize(APP_CONFIG_PATH) unless APP_CONFIG_PATH.nil?
      rescue Longleaf::ConfigurationError => e
        warn "WARN: Failed to load Longleaf application configuration: #{e.message}"
        nil
      end

      class << self
        attr_accessor :app_manager
      end

      error do |e|
        warn "ERROR [#{e.class}]: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
        response.status = 500
        { error: e.message }
      end

      route do |r|
        # All endpoints are nested under /api
        r.on 'api' do
          # POST /api/register
          r.on 'register' do
            r.post do
              Controllers::RegisterController.new(self.class.app_manager).handle(r)
            end
          end

          # DELETE /api/deregister
          r.on 'deregister' do
            r.delete do
              Controllers::DeregisterController.new(self.class.app_manager).handle(r)
            end
          end
        end
      end
    end
  end
end
