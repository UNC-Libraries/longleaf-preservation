# Longleaf
Code: [![CI](https://github.com/UNC-Libraries/longleaf-preservation/actions/workflows/build.yml/badge.svg)](https://github.com/UNC-Libraries/longleaf-preservation/actions/workflows/build.yml)

Longleaf is a command-line tool which allows users to configure a set of storage locations and define custom sets of preservation services to run on their contents. These services are executed in response to applicable preservation events issued by clients. Its primary goal is to provide tools to create a simple and customizable preservation environment. Longleaf:

* Offers a predictable command-line interface and integrates with standard command-line tools.
* Offers configurable and customizable criteria based preservation workflows.
* Provides a base set of tools and a framework for building extensions.
* Provides activity logging and notifications.
* Performs preservation services only when required.

## Installation

There are two primary ways to install Longleaf, depending on how you intend to use it:

#### Standalone gem

To use Longleaf as a command-line application, the gem can be installed using:

```
$ gem install longleaf
```

Or it may be built from source:

```
$ git clone git@github.com:UNC-Libraries/longleaf-preservation.git
$ cd longleaf-preservation
$ bin/setup
$ lock_jars               # JRuby only — downloads ocfl-java JARs; skip on CRuby
$ bundle exec rake install # builds the gem
$ gem install --local pkg/longleaf* # installs gem
```

#### Applicaton dependency

To make use of longleaf as a dependency of your application, add this line to your application's Gemfile:

```ruby
gem 'longleaf'
```

And then execute:

```
$ bundle
```

## Usage

#### Register a file
In order to register a new file with Longleaf, use the register command:

```
longleaf register -c <config.yml> -f <path to file>
```

In the case that a file's content is replaced, the file can be re-registered by providing the `--force` flag.

#### Validate configuration files
Application configuration files can be validated prior to usage with the following command:

```
longleaf validate_config -c <config.yml>
```

#### Output and logging

The primary output from Longleaf is directed to STDOUT, and contains both success and failure messages. If you would like to only return failure messages, you may provide the `--failure_only` flag.

Additional logging is sent to STDERR. To control the level of logging, you may provide the `--log-level` parameter, which expects the standard [Ruby Logger levels](https://ruby-doc.org/stdlib-2.4.0/libdoc/logger/rdoc/Logger.html). The default log level is 'WARN'.

Messages sent to STDOUT are duplicated to STDERR at 'INFO' level, so they are excluded by default. In order to store an ongoing log of activity and errors, you would perform the following:

```
longleaf <command> --log-level 'INFO' 2> /logs/longleaf.log
```

## Web Server

Longleaf can also run as an HTTP API server using [Puma](https://puma.io) and [Roda](https://roda.jeremyevans.net), exposing the same preservation operations that are available on the command line.

#### Configuration

Each server instance is bound to a single application configuration file, specified via the `LONGLEAF_CFG` environment variable — mirroring the `-c` flag used by the CLI. If you have multiple configuration files, run one server instance per config.

#### Starting the server

```
LONGLEAF_CFG=/path/to/config.yml bundle exec puma -C config/puma.rb
```

The following environment variables control server behaviour (all optional):

| Variable | Default | Description |
|---|---|---|
| `LONGLEAF_CFG` | _(none)_ | Path to the Longleaf application configuration file |
| `LONGLEAF_API_KEYS` | _(none)_ | Comma-separated list of accepted API keys (see [Authentication](#authentication)) |
| `PORT` | `3000` | Port to listen on |
| `RACK_ENV` | `development` | Rack environment (`development`, `production`) |
| `PUMA_THREADS` | `5` | Min and max threads per worker |
| `WEB_CONCURRENCY` | `1` | Number of Puma worker processes, only for CRuby |

For production use, set `WEB_CONCURRENCY` to the number of CPU cores available and `RACK_ENV=production`:

```
LONGLEAF_CFG=/path/to/config.yml \
  RACK_ENV=production \
  PORT=3000 \
  PUMA_THREADS=16 \
  bundle exec puma -C config/puma.rb
```

To run a second instance against a different config on a different port:

```
LONGLEAF_CFG=/path/to/other_config.yml PORT=3001 bundle exec puma -C config/puma.rb
```

#### Authentication

API key authentication is optional but recommended for any network-accessible deployment. When `LONGLEAF_API_KEYS` is set, every request to `/api/*` must include a matching key in the `X-Api-Key` header. Requests with a missing or unrecognised key receive a `401 Unauthorized` response. If no keys are configured, all requests are allowed through.

Set one or more accepted keys (comma-separated) at server startup:

```
LONGLEAF_CFG=/path/to/config.yml \
  LONGLEAF_API_KEYS=key-one,key-two \
  bundle exec puma -C config/puma.rb
```

Clients supply the key as a request header:

```
curl -X POST http://localhost:3000/api/register \
  -H 'Content-Type: application/json' \
  -H 'X-Api-Key: key-one' \
  -d '{"file": "/storage/loc1/image.tif"}'
```

#### API endpoints

All endpoints accept and return JSON. A `200 OK` response indicates success. Non-2xx responses include an `error` key in the JSON body.

---

**`POST /api/register`** — Register one or more files.

| Parameter | Type | Description |
|---|---|---|
| `file` | string | Comma-separated logical file paths to register. Mutually exclusive with `manifest` and `from_list`. |
| `manifest` | array of strings | Checksum manifest values (same format as the CLI `-m` option). Mutually exclusive with `file` and `from_list`. |
| `from_list` | string | Path to a newline-separated file list on the server filesystem. Mutually exclusive with `file` and `manifest`. |
| `physical_path` | string | Comma-separated physical paths, paired with `file`, for files where the logical and physical paths differ. |
| `checksums` | string | Comma-separated `algorithm:digest` pairs to associate with the file, e.g. `"md5:abc123,sha1:def456"`. Only applicable with `file`. |
| `force` | boolean | Re-register already-registered files. |
| `ocfl` | boolean | Treat targets as OCFL object directories. |

Example:
```
curl -X POST http://localhost:3000/api/register \
  -H 'Content-Type: application/json' \
  -H 'X-Api-Key: <your-api-key>' \
  -d '{"file": "/storage/loc1/image.tif"}'
```

---

**`DELETE /api/deregister`** — Deregister one or more files.

| Parameter | Type | Description |
|---|---|---|
| `file` | string | Comma-separated logical file paths to deregister. Mutually exclusive with `location` and `from_list`. |
| `location` | string | Comma-separated storage location names; deregisters all registered files within those locations. Mutually exclusive with `file` and `from_list`. |
| `from_list` | string | Path to a newline-separated file list on the server filesystem. Mutually exclusive with `file` and `location`. |
| `force` | boolean | Deregister files that are already deregistered. |

Example:
```
curl -X POST http://localhost:3000/api/deregister \
  -H 'Content-Type: application/json' \
  -H 'X-Api-Key: <your-api-key>' \
  -d '{"file": "/storage/loc1/image.tif"}'
```

---

## Development

After checking out the repo, run `bin/setup` to install dependencies.

#### JRuby and Java dependencies (OCFL support)

OCFL features (`OcflStorageLocation`, `OcflValidationService`, etc.) require JRuby and are backed by [ocfl-java](https://github.com/OCFL/ocfl-java). JAR dependency management is handled by [jar-dependencies](https://github.com/mkristian/jar-dependencies), which is bundled with JRuby.

If you are running under JRuby you must download the required JARs after `bundle install`:

```
bundle install
lock_jars
```

`lock_jars` is provided by JRuby's bundled `jar-dependencies` gem (typically at `$(rbenv prefix)/bin/lock_jars` or equivalent). It reads the `Jarfile`, resolves all Maven dependencies (including transitive ones) from Maven Central into `~/.m2/repository`, and writes a pinned `Jars.lock`. Commit `Jars.lock` so that CI and other developers use the same resolved versions.

For deployment scripts, call `lock_jars` by its absolute path to avoid PATH or Bundler issues:

```
/path/to/jruby/bin/lock_jars
```

#### Running tests

To perform the tests, run:
```
bundle exec rspec
```

To run Longleaf with local changes without needing to do a local install, you may run:
```
bundle exec exe/longleaf <command>
```

To install this gem onto your local machine, run:
```
bundle exec rake install
```

This places a newly built gem into the `pkg/` directory. This gem may then be installed in order to run commands in the `longleaf <command>` form.
_Note:_ Only files committed to git will be included in the installed gem.

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Indexing
To use an index to improve performance, you will need to install the database drivers separately or bundle longleaf with the driver you wish to use:

```
bundle install --with postgres
```

Options include: postgres, mysql2, mysql, sqlite, amalgalite

To setup an index, you will need to add a `system > index` section to your configuration with the details of the database to use for the index. Then to setup the database, run:

```
longleaf setup_index -c <config_file>
```
And for a one-time indexing:
```
longleaf reindex -c <config_file>
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/UNC-Libraries/longleaf-preservation.


## License

The gem is available as open source under the terms of the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

