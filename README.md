# Longleaf
Code: [![CircleCI](https://circleci.com/gh/UNC-Libraries/longleaf-preservation.svg?style=svg)](https://circleci.com/gh/UNC-Libraries/longleaf-preservation)

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

## Development

After checking out the repo, run `bin/setup` to install dependencies. 

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

