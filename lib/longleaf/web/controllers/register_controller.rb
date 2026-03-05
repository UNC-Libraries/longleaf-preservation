require 'longleaf/commands/register_command'
require 'longleaf/events/event_names'
require 'longleaf/helpers/selection_options_parser'
require 'longleaf/errors'
require 'longleaf/logging'

module Longleaf
  module Web
    module Controllers
      # HTTP controller for the register event endpoint.
      #
      # Maps a POST /api/register request to the same RegisterCommand that the
      # CLI uses. Request parameters mirror the CLI flags as closely as possible.
      #
      # Expected request body (JSON or form-encoded):
      #   file          - Comma-separated logical file paths to register (required
      #                   unless `manifest` is provided).
      #   manifest      - Checksum manifest values, same format as CLI -m option.
      #                   Provided as a JSON array of strings.
      #   physical_path - Comma-separated physical paths, paired with `file`.
      #   checksums     - Comma-separated algorithm:digest pairs, e.g.
      #                   "md5:abc123,sha1:def456"
      #   force         - Boolean; re-register already-registered files.
      #   ocfl          - Boolean; treat targets as OCFL object directories.
      #
      # Returns JSON:
      #   202 Accepted  on success
      #   400 Bad Request  when required parameters are missing or malformed
      #   500 Internal Server Error  on unexpected failures
      class RegisterController
        include Longleaf::Logging

        # @param app_manager [ApplicationConfigManager] loaded application config
        def initialize(app_manager)
          @app_manager = app_manager
        end

        # Handle an incoming Roda request for the register endpoint.
        # @param request [Roda::RodaRequest]
        # @return [Hash] JSON-serialisable response body (Roda serialises it automatically)
        def handle(request)
          error_response(request, 503, 'Application configuration is not loaded') if @app_manager.nil?

          params = extract_params(request)

          file_selector, digest_provider, physical_provider =
            parse_selection_options(params, request)

          command = RegisterCommand.new(@app_manager)
          status  = command.execute(
            file_selector:     file_selector,
            force:             params[:force],
            digest_provider:   digest_provider,
            physical_provider: physical_provider
          )
          outcome = command.outcome_summary(EventNames::REGISTER)

          request.response.status = status == 0 ? 202 : 500
          outcome
        end

        private

        # Build a symbol-keyed options hash from request parameters that matches
        # the shape expected by SelectionOptionsParser.
        def extract_params(request)
          body = request.params

          {
            file:          presence(body['file']),
            manifest:      presence(body['manifest']),
            from_list:     presence(body['from_list']),
            checksums:     presence(body['checksums']),
            physical_path: presence(body['physical_path']),
            force:         truthy?(body['force']),
            ocfl:          truthy?(body['ocfl'])
          }
        end

        # Delegate to SelectionOptionsParser, mapping SelectionError validation
        # failures to HTTP 400 responses via Roda's halt mechanism.
        def parse_selection_options(params, request)
          SelectionOptionsParser.parse_registration_selection_options(params, @app_manager)
        rescue Longleaf::SelectionError => e
          request.halt [400, { 'content-type' => 'application/json' },
                        [%({"error":#{e.message.to_json}})]]
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
