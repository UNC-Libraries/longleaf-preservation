if RUBY_ENGINE == 'jruby'
  require 'java'
  ENV['JARS_LOCK'] = File.expand_path('Jars.lock', __dir__)
  ENV['JARS_HOME'] = File.join(ENV_JAVA['user.home'], '.m2', 'repository')
  require 'jars/setup'
end

require_relative 'lib/longleaf/web/app'

run Longleaf::Web::App.freeze.app
