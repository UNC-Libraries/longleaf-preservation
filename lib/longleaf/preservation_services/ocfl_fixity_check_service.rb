unless RUBY_ENGINE == 'jruby'
  raise LoadError, "OcflFixityCheckService requires JRuby — ocfl-java is not available on CRuby."
end

require 'longleaf/events/event_names'
require 'longleaf/logging'

# JRuby-specific: load the ocfl-java classes via jar-dependencies
require 'jars/setup'   # ensures jar-dependencies has loaded the jars
java_import 'edu.wisc.library.ocfl.api.OcflRepository'
java_import 'edu.wisc.library.ocfl.core.OcflRepositoryBuilder'

module Longleaf
  class OcflFixityCheckService
    include Longleaf::Logging
    # ...
  end
end