require 'longleaf/logging'

module Longleaf
  module Web
    module Controllers
      # HTTP controller for the jobs status endpoint.
      #
      # Maps a GET /api/jobs/:id request to a lookup in the JobRegistry.
      #
      # Returns JSON:
      #   200 OK   with job details when the id is found:
      #     { id:, status:, started_at:, completed_at: }
      #   404 Not Found  when the id is unknown or has been pruned
      #
      # GET /api/jobs returns JSON:
      #   200 OK   with an array of all job entries (may be empty)
      class JobsController
        include Longleaf::Logging

        # @param job_registry [JobRegistry] shared job registry
        def initialize(job_registry)
          @job_registry = job_registry
        end

        # Handle an incoming Roda request for the jobs list endpoint.
        # @param request [Roda::RodaRequest]
        # @return [Array] JSON-serialisable array of all job entries
        def list(request)
          @job_registry.list.map { |job| serialize(job) }
        end

        # Handle an incoming Roda request for the jobs status endpoint.
        # @param request [Roda::RodaRequest]
        # @param job_id  [String] the job UUID from the URL segment
        # @return [Hash] JSON-serialisable response body
        def handle(request, job_id)
          job = @job_registry.find(job_id)

          if job.nil?
            request.halt [404, { 'content-type' => 'application/json' },
                          [{ error: 'Job not found' }.to_json]]
          end

          serialize(job)
        end

        private

        def serialize(job)
          {
            id:           job[:id],
            status:       job[:status],
            started_at:   job[:started_at],
            completed_at: job[:completed_at]
          }
        end
      end
    end
  end
end
