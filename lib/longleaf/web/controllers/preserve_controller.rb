require 'longleaf/commands/preserve_command'
require 'longleaf/events/event_names'
require 'longleaf/helpers/selection_options_parser'
require 'longleaf/errors'
require 'longleaf/logging'
require 'concurrent'
require 'stringio'

module Longleaf
  module Web
    module Controllers
      # HTTP controller for the preserve event endpoint.
      #
      # Maps a POST /api/preserve request to the same PreserveCommand that the
      # CLI uses. The command is executed asynchronously on the IO thread pool;
      # the request returns immediately with 202 Accepted and a job_id that can
      # be used to poll GET /api/jobs/:id for completion status.
      #
      # Parameters mirror the CLI flags as closely as possible.
      #
      # Expected request body (JSON or form-encoded):
      #   file      - Comma-separated logical file paths to preserve. Mutually
      #               exclusive with `location` and `from_list`.
      #   location  - Comma-separated storage location names to preserve all
      #               registered files from. Mutually exclusive with `file` and
      #               `from_list`.
      #   from_list - Path to a newline-separated file list on the server
      #               filesystem, or '@-' to read from the `body` parameter.
      #               Mutually exclusive with `file` and `location`.
      #   body      - Inline content to be streamed when `from_list` is '@-'.
      #               Replaces CLI piped stdin.
      #   force     - Boolean; force execution of preservation services,
      #               disregarding scheduling information.
      #
      # Returns JSON:
      #   202 Accepted  with { job_id: "..." } on successful dispatch
      #   400 Bad Request  when required parameters are missing or malformed
      #   503 Service Unavailable  when app configuration is not loaded
      class PreserveController
        include Longleaf::Logging

        # @param app_manager [ApplicationConfigManager] loaded application config
        # @param job_registry [JobRegistry] shared job registry for tracking async runs
        def initialize(app_manager, job_registry)
          @app_manager  = app_manager
          @job_registry = job_registry
        end

        # Handle an incoming Roda request for the preserve endpoint.
        # Validates parameters synchronously, then dispatches the PreserveCommand
        # to a background thread and returns 202 with a job_id immediately.
        # @param request [Roda::RodaRequest]
        # @return [Hash] JSON-serialisable response body containing :job_id
        def handle(request)
          error_response(request, 503, 'Application configuration is not loaded') if @app_manager.nil?

          params = extract_params(request)

          input_stream = params[:body] ? StringIO.new(params[:body]) : nil

          validate_stream_params(params, input_stream, request)

          file_selector = build_file_selector(params, input_stream, request)

          job_id = @job_registry.register(
            file:      params[:file],
            location:  params[:location],
            from_list: params[:from_list],
            force:     params[:force]
          )

          dispatch_job(job_id, file_selector, params[:force])

          request.response.status = 202
          { job_id: job_id }
        end

        private

        # Launch the PreserveCommand on the IO thread pool and update the registry
        # when it finishes.  Captures all exceptions so the registry is always
        # transitioned out of :running.
        def dispatch_job(job_id, file_selector, force)
          app_manager  = @app_manager
          job_registry = @job_registry

          Concurrent::Promises.future_on(:io, job_id, file_selector, force) do |jid, selector, f|
            begin
              command = PreserveCommand.new(app_manager)
              command.execute(file_selector: selector, force: f)
              job_registry.complete(jid)
            rescue => e
              Longleaf::Logging.logger.error("Preserve job #{jid} raised an unexpected error: #{e.message}")
              job_registry.fail(jid)
            end
          end
        end

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
