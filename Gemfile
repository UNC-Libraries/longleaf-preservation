source 'https://rubygems.org'

gemspec

# On JRuby, jdbc-sqlite3 must be explicitly listed here (not only in the gemspec)
# to ensure Bundler places it on the load path for tests and CLI use.
if RUBY_ENGINE == 'jruby'
  gem 'jdbc-sqlite3'
end

group :postgres, optional: true do
  if RUBY_ENGINE == 'jruby'
    gem 'jdbc-postgres'
  else
    gem 'pg', '1.4.6'
  end
end

group :sqlite, optional: true do
  unless RUBY_ENGINE == 'jruby'
    gem 'sqlite3'
  end
end

group :mysql2, optional: true do
  if RUBY_ENGINE == 'jruby'
    gem 'jdbc-mysql'
  else
    gem 'mysql2', ">= 0.5.0"
  end
end

group :mysql, optional: true do
  if RUBY_ENGINE == 'jruby'
    gem 'jdbc-mysql'
  else
    gem 'mysql'
  end
end
