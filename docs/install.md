# Installing Longleaf

### Ruby and other Prerequisites
Longleaf requires Ruby 2.3 or higher.

There also are optional gem dependencies if the user wishes to use an index to improve performance.

Additionally, Longleaf scripts rely on common Unix programs. In Mac OS X and Linux operating systems, these programs will likely already be installed, but some of these tools, such as `rsync` may be missing from a Windows system unless you have installed them.

### Download Longleaf
Download Longleaf from UNC Chapel Hill's University Libraries [Longleaf github repository](https://github.com/UNC-Libraries/longleaf-preservation).

### Install Longleaf

There are two ways to install Longleaf, depending on how you intend to use it:

**1. Standalone gem**

To use Longleaf as a command-line application, the gem can be installed using:

    $ gem install longleaf

Or it may be built from source:

    $ git clone git@github.com:UNC-Libraries/longleaf-preservation.git
    $ cd longleaf-preservation
    $ bin/setup --system
    $ bundle exec rake install # builds the gem
    $ gem install --local pkg/longleaf* # installs gem

**2. Application dependency**

To include longleaf as a dependency in an application, add this line to your application's Gemfile:

```ruby
gem 'longleaf'
```

And then execute:

    $ bundle

### Confirm Longleaf Installation
If you have installed Longleaf using the "Standalone gem" approach, you can check to make sure that the installation succeeded by typing the following into your terminal:

```
longleaf
```

You should see the Longleaf help page:   
```
Commands:
  longleaf --version          # Prints the Longleaf version number.
  longleaf deregister         # Deregister files with Longleaf
  longleaf help [COMMAND]     # Describe available commands or one specific command
  longleaf preserve           # Perform preservation services on files with Longleaf
  longleaf register           # Register files with Longleaf
  longleaf reindex            # Perform a full reindex of file metadata stored within the configured storage locations.
  longleaf setup_index        # Sets up the structure of the metadata index, if one is configured using the system configuration file provide...
  longleaf validate_config    # Validate an application configuration file, provided using --config.
  longleaf validate_metadata  # Validate metadata files.


```
### Installation Success!   
If the Longleaf Help page printed successfully, you are ready to proceed to the [Basic Usage tutorial](quickstart.md) to try out basic Longleaf functionality.
