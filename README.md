# Longleaf
Longleaf is a command-line tool which allows users to configure a set of storage locations and define custom sets of preservation services to run on their contents. These services are executed in response to applicable preservation events issued by clients.

It's primary goal is to provide tools to create a simple and customizable preservation environment.  Longleaf:

* Offers a predictable command-line interface and integrates with standard command-line tools.
* Offers configurable and customizable criteria based preservation workflows.
* Provides a base set of tools and a framework for building extensions.
* Provides activity logging and notifications.
* Performs preservation services only when required.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'longleaf'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install longleaf

## Usage

#### Register a file
In order to register a new file with Longleaf, use the register command:
`longleaf register -c <config.yml> -f <path to file>`

In the case that a file's content is replaced, the file can be re-registered by providing the `--force` flag.

#### Validate configuration files
Application configuration files can be validated prior to usage with the following command:
`longleaf validate_config -c <config.yml>`

#### Output and logging

The primary output from Longleaf is directed to STDOUT, and contains both success and failure messages. If you would like to only return failure messages, you may provide the `--failure_only` flag.

Additional logging is sent to STDERR. To control the level of logging, you may provide the `--log-level` parameter, which expects the standard Ruby Logger levels. The default log level is 'WARN'.

Messages sent to STDOUT are duplicated to STDERR at 'INFO' level, so they are excluded by default. In order to store an ongoing log of activity and errors, you would perform the following:
`longleaf <command> --log-level 'INFO' 2> /logs/longleaf.log`

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To run Longleaf with local changes without needing to do a local install, you may run `bundle exec exe/longleaf <command>`.

To install this gem onto your local machine, run `bundle exec rake install`. This will allow you to run `longleaf <command>` and places the gem into `pkg/`. Note: Only files committed to git will be included in the installed gem.

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://gitlab.lib.unc.edu/cdr/longleaf.


## License

The gem is available as open source under the terms of the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

