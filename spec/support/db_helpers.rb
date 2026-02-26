module Longleaf
  # Helper methods for constructing database adapter names and connection strings in tests.
  # The active backend is controlled by the TEST_DATABASE environment variable:
  #   TEST_DATABASE=sqlite   (default) — uses amalgalite (CRuby) or jdbc-sqlite3 (JRuby)
  #   TEST_DATABASE=postgres           — uses pg (CRuby) or jdbc-postgres (JRuby)
  #
  # For PostgreSQL, the connection URL is read from TEST_PG_URL, defaulting to:
  #   postgres://postgres:postgres@localhost/longleaf_test
  module DbHelpers
    POSTGRES_BACKEND = 'postgres'.freeze

    # Returns true when PostgreSQL has been selected via TEST_DATABASE=postgres
    def postgres_db_mode?
      ENV.fetch('TEST_DATABASE', 'sqlite') == POSTGRES_BACKEND
    end

    # Returns the adapter string/symbol appropriate for the active backend and Ruby engine.
    # Callers that require a symbol (e.g. SequelIndexDriver) can call .to_sym on the result.
    def test_db_adapter
      if postgres_db_mode?
        RUBY_ENGINE == 'jruby' ? 'jdbc' : 'postgres'
      else
        RUBY_ENGINE == 'jruby' ? 'jdbc' : 'amalgalite'
      end
    end

    # Returns a Sequel-compatible connection string for the active backend.
    #
    # @param db_file [String, nil] path to the SQLite database file — required when using
    #   the sqlite backend, ignored for postgres.
    def test_db_conn_str(db_file = nil)
      if postgres_db_mode?
        pg_url = ENV.fetch('TEST_PG_URL', 'postgres://postgres:postgres@localhost/longleaf_test')
        if RUBY_ENGINE == 'jruby'
          pg_url.sub(/\Apostgres:\/\//, 'jdbc:postgresql://')
        else
          pg_url
        end
      else
        raise ArgumentError, 'db_file is required for the sqlite backend' if db_file.nil?
        RUBY_ENGINE == 'jruby' ? "jdbc:sqlite:#{db_file}" : "amalgalite://#{db_file}"
      end
    end
  end
end
