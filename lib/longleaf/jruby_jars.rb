# Loads JRuby JAR dependencies declared in Jars.lock directly from the local
# Maven repository. This bypasses jar-dependencies' home-detection logic, which
# can fail in subprocesses (e.g. aruba CLI tests) where HOME or ENV_JAVA
# resolution is unreliable.
#
# Only called when RUBY_ENGINE == 'jruby'.

module Longleaf
  module JrubyJars
    JARS_LOCK = File.expand_path('../../../Jars.lock', __FILE__).freeze

    # Locate the Maven local repository. Checks env vars first, then falls back
    # to the standard ~/.m2/repository path using the Java user.home property
    # (which is always available in JRuby regardless of the shell environment).
    def self.maven_repo
      ENV['JARS_LOCAL_MAVEN_REPO'] ||
        ENV['JARS_HOME'] ||
        File.join(ENV_JAVA['user.home'], '.m2', 'repository')
    end

    # Require all runtime-scoped JARs listed in Jars.lock.
    def self.load!
      return unless File.exist?(JARS_LOCK)

      repo = maven_repo

      File.read(JARS_LOCK).each_line do |line|
        line = line.strip
        # Lines without at least two colons are comments / blank
        next unless line.count(':') >= 3

        # Use -1 limit so trailing empty field from the line's trailing colon
        # is preserved; without it Ruby strips it and index arithmetic breaks.
        parts = line.split(':', -1)
        # Jars.lock format:  group_id:artifact_id:version:scope:
        # With classifier:   group_id:artifact_id:classifier:version:scope:
        scope = parts[-2].to_s.strip
        next if scope == 'test' || scope == 'provided'

        group_id    = parts[0]
        artifact_id = parts[1]
        version     = parts[-3].strip
        classifier  = parts.size >= 6 ? parts[2] : nil

        jar_name  = "#{artifact_id}-#{version}#{classifier ? "-#{classifier}" : ''}.jar"
        jar_path  = File.join(repo, group_id.tr('.', '/'), artifact_id, version, jar_name)

        require jar_path if File.exist?(jar_path)
      end
    end
  end
end

Longleaf::JrubyJars.load!
