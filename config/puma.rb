# Puma configuration for the Longleaf web server.
# All values can be overridden via environment variables.

port        ENV.fetch('PORT', 3000)
environment ENV.fetch('RACK_ENV', 'development')

threads_count = ENV.fetch('PUMA_THREADS', 5).to_i
threads threads_count, threads_count

# Redirect stdout and stderr to log files so that application log output
# (written by RedirectingLogger to $stdout/$stderr) is persisted on disk.
# Defaults place logs under /var/log/longleaf/; override via environment
# variables when running under systemd or another process supervisor.
log_dir = ENV.fetch('LONGLEAF_LOG_DIR', '/var/log/longleaf')
stdout_redirect \
  File.join(log_dir, 'longleaf.log'),
  File.join(log_dir, 'longleaf-error.log'),
  true # this opens the files in append mode.

# JRuby runs on the JVM which does not support fork(), so worker (multi-process)
# mode is unavailable. Use threaded mode (single worker) instead.
# On MRI Ruby, WEB_CONCURRENCY controls the number of worker processes.
unless RUBY_ENGINE == 'jruby'
  workers ENV.fetch('WEB_CONCURRENCY', 1).to_i

  preload_app!

  before_worker_boot do
    # Re-establish any resources that are not fork-safe here (e.g. DB connections).
  end
end
