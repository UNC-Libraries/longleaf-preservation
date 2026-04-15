require 'securerandom'

module Longleaf
  module Web
    # Thread-safe in-memory registry of background preserve jobs.
    #
    # Jobs are stored until they have been completed/failed for at least
    # JOB_TTL seconds, after which they are pruned lazily on the next
    # registration call.
    class JobRegistry
      # How long (in seconds) a finished job remains queryable after completion.
      JOB_TTL = 4 * 60 * 60 # 4 hours

      def initialize
        @jobs  = {}
        @mutex = Mutex.new
      end

      # Register a new job and return its UUID.
      # @param params [Hash] a sanitised subset of the request params for display/logging
      # @return [String] the new job id
      def register(params = {})
        prune_expired
        id = SecureRandom.uuid
        @mutex.synchronize do
          @jobs[id] = {
            id:           id,
            status:       :running,
            params:       params,
            started_at:   Time.now,
            completed_at: nil
          }
        end
        id
      end

      # Mark a job as successfully completed.
      # @param id [String] job id returned by #register
      def complete(id)
        update_status(id, :complete)
      end

      # Mark a job as failed.
      # @param id [String] job id returned by #register
      def fail(id)
        update_status(id, :failed)
      end

      # Return a snapshot of the job entry, or nil if not found.
      # @param id [String] job id
      # @return [Hash, nil]
      def find(id)
        @mutex.synchronize { @jobs[id]&.dup }
      end

      # Return a snapshot of all jobs in the registry.
      # @return [Array<Hash>]
      def list
        @mutex.synchronize { @jobs.values.map(&:dup) }
      end

      private

      def update_status(id, status)
        @mutex.synchronize do
          return unless @jobs[id]
          @jobs[id][:status]       = status
          @jobs[id][:completed_at] = Time.now
        end
      end

      def prune_expired
        cutoff = Time.now - JOB_TTL
        @mutex.synchronize do
          @jobs.delete_if do |_, job|
            job[:status] != :running &&
              job[:completed_at] &&
              job[:completed_at] < cutoff
          end
        end
      end
    end
  end
end
