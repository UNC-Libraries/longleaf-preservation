require 'longleaf/commands/register_command'
require 'longleaf/helpers/selection_options_parser'
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
          return error_response(503, 'Application configuration is not loaded') if @app_manager.nil?

          params = extract_params(request)

          file_selector, digest_provider, physical_provider =
            parse_selection_options(params, request)

          return if request.halt?  # parse_selection_options may have halted

          command = RegisterCommand.new(@app_manager)
          status  = command.execute(
            file_selector:     file_selector,
            force:             params[:force],
            digest_provider:   digest_provider,
            physical_provider: physical_provider
          )

          if status == 0
            request.response.status = 202
            { status: 'success' }
          else
            error_response(500, 'Register command completed with failures')
          end
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

        # Delegate to SelectionOptionsParser, translating its `exit` calls into
        # HTTP 400 responses via Roda's halt mechanism.
        #
        # TODO: SelectionOptionsParser currently calls Kernel#exit on validation
        # failures, which is not safe in a long-running server context. Once the
        # web layer matures, SelectionOptionsParser (or a web-specific variant)
        # should raise structured errors instead. For now, SystemExit is caught
        # and converted to a 400 Bad Request.
        def parse_selection_options(params, request)
          SelectionOptionsParser.parse_registration_selection_options(params, @app_manager)
        rescue SystemExit
          request.halt [400, { 'content-type' => 'application/json' },
                        ['{"error":"Invalid or missing file selection parameters"}']]
        rescue StandardError => e
          request.halt [400, { 'content-type' => 'application/json' },
                        [%({"error":#{e.message.to_json}})]]
        end

        def error_response(status_code, message)
          # Reached only when we are NOT using request.halt (caller checks itself)
          raise Roda::RodaError, "#{status_code}: #{message}"
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
