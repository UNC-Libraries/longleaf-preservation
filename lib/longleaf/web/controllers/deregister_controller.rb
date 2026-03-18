require 'longleaf/commands/deregister_command'
require 'longleaf/events/event_names'
require 'longleaf/helpers/selection_options_parser'
require 'longleaf/errors'
require 'longleaf/logging'
require 'stringio'

module Longleaf
  module Web
    module Controllers
      # HTTP controller for the deregister event endpoint.
      #
      # Maps a DELETE /api/deregister request to the same DeregisterCommand that
      # the CLI uses. Parameters mirror the CLI flags as closely as possible.
      #
      # Expected request body (JSON or form-encoded):
      #   file     - Comma-separated logical file paths to deregister. Mutually
      #              exclusive with `location` and `from_list`.
      #   location - Comma-separated storage location names to deregister all
      #              registered files from. Mutually exclusive with `file` and
      #              `from_list`.
      #   from_list - Path to a newline-separated file list on the server
      #               filesystem, or '@-' to read from the `body` parameter.
      #               Mutually exclusive with `file` and `location`.
      #   body     - Inline content to be streamed when `from_list` is '@-'.
      #              Replaces CLI piped stdin.
      #   force    - Boolean; deregister files that are not currently registered.
      #
      # Returns JSON:
      #   202 Accepted  on success
      #   400 Bad Request  when required parameters are missing or malformed
      #   500 Internal Server Error  on unexpected failures
      #   503 Service Unavailable  when app configuration is not loaded
      class DeregisterController
        include Longleaf::Logging

        # @param app_manager [ApplicationConfigManager] loaded application config
        def initialize(app_manager)
          @app_manager = app_manager
        end

        # Handle an incoming Roda request for the deregister endpoint.
        # @param request [Roda::RodaRequest]
        # @return [Hash] JSON-serialisable response body
        def handle(request)
          error_response(request, 503, 'Application configuration is not loaded') if @app_manager.nil?

          params = extract_params(request)

          input_stream = params[:body] ? StringIO.new(params[:body]) : nil

          validate_stream_params(params, input_stream, request)

          file_selector = build_file_selector(params, input_stream, request)

          command = DeregisterCommand.new(@app_manager)
          status  = command.execute(
            file_selector: file_selector,
            force:         params[:force]
          )
          outcome = command.outcome_summary(EventNames::DEREGISTER)

          request.response.status = status == 0 ? 202 : 500
          outcome
        end

        private

        def extract_params(request)
          body = request.params

          {
            file:      presence(body['file']),
            location:  presence(body['location']),
            from_list: presence(body['from_list']),
            body:      presence(body['body']),
            force:     truthy?(body['force'])
          }
        end

        # Delegate to SelectionOptionsParser, mapping SelectionError validation
        # failures to HTTP 400 responses via Roda's halt mechanism.
        def build_file_selector(params, input_stream, request)
          stream_args = input_stream ? { input_stream: input_stream } : {}
          SelectionOptionsParser.create_registered_selector(params, @app_manager, **stream_args)
        rescue Longleaf::SelectionError => e
          request.halt [400, { 'content-type' => 'application/json' },
                        [%({"error":#{e.message.to_json}})]]
        end

        def validate_stream_params(params, input_stream, request)
          return if input_stream
          if params[:from_list] == '@-'
            error_response(request, 400, "A 'body' parameter is required when '@-' is specified")
          end
        end

        def error_response(request, status_code, message)
          request.halt [status_code, { 'content-type' => 'application/json' },
                        [{ error: message }.to_json]]
        end

        def presence(value)
          return nil if value.nil? || (value.respond_to?(:empty?) && value.empty?)
          value
        end

        def truthy?(value)
          return false if value.nil?
          %w[true 1 yes].include?(value.to_s.downcase)
        end
      end
    end
  end
end
