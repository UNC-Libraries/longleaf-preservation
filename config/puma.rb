# Puma configuration for the Longleaf web server.
# All values can be overridden via environment variables.

port        ENV.fetch('PORT', 3000)
environment ENV.fetch('RACK_ENV', 'development')

threads_count = ENV.fetch('PUMA_THREADS', 5).to_i
threads threads_count, threads_count

# Redirect stdout and stderr to log files.
# When LONGLEAF_LOG_ROTATION=daily, Longleaf writes its own files directly and
# Puma output is sent to separate puma.log / puma-error.log files.
# Otherwise, Puma captures the combined application and process output in the
# original longleaf.log / longleaf-error.log files.
log_dir = ENV.fetch('LONGLEAF_LOG_DIR', '/var/log/longleaf')
log_rotation = ENV.fetch('LONGLEAF_LOG_ROTATION', '').strip.downcase

stdout_log_name = log_rotation == 'daily' ? 'puma.log' : 'longleaf.log'
stderr_log_name = log_rotation == 'daily' ? 'puma-error.log' : 'longleaf-error.log'

stdout_redirect \
  File.join(log_dir, stdout_log_name),
  File.join(log_dir, stderr_log_name),
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
