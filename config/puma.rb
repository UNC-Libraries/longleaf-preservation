# Puma configuration for the Longleaf web server.
# All values can be overridden via environment variables.

port        ENV.fetch('PORT', 3000)
environment ENV.fetch('RACK_ENV', 'development')

threads_count = ENV.fetch('PUMA_THREADS', 5).to_i
threads threads_count, threads_count

# Use a single worker in development; set WEB_CONCURRENCY > 1 for production.
workers ENV.fetch('WEB_CONCURRENCY', 1).to_i

preload_app!

on_worker_boot do
  # Re-establish any resources that are not fork-safe here (e.g. DB connections).
end
