module Longleaf
  module Web
    module Controllers
      # HTTP controller for the application health endpoint.
      class HealthcheckController
        # @param app_manager [ApplicationConfigManager, nil] loaded application config
        def initialize(app_manager)
          @app_manager = app_manager
        end

        # @param request [Roda::RodaRequest]
        # @return [Hash] JSON-serialisable response body
        def handle(request)
          unless @app_manager
            request.halt [503, { 'content-type' => 'application/json' },
                          [{ status: 'unavailable' }.to_json]]
          end

          { status: 'ok' }
        end
      end
    end
  end
end
