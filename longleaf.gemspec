# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'longleaf/version'

Gem::Specification.new do |spec|
  spec.name          = "longleaf"
  spec.version       = Longleaf::VERSION
  spec.authors       = ["Ben Pennell"]
  spec.email         = ["bbpennel@email.unc.edu"]

  spec.summary       = %q{Longleaf preservation services tool}
  spec.description   = %q{Longleaf is a command-line tool which allows users to configure a set of storage locations and define custom sets of preservation services to run on their contents. These services are executed in response to applicable preservation events issued by clients. Its primary goal is to provide tools to create a simple and customizable preservation environment.}
  spec.homepage      = "https://unc-libraries.github.io/longleaf-preservation"
  spec.metadata         = { "source_code_uri" => "https://github.com/UNC-Libraries/longleaf-preservation" }
  spec.license       = "Apache-2.0"

  spec.required_ruby_version = '>= 2.3'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = "longleaf"
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 1.2.0"
  spec.add_dependency "yard", "~> 0.9.16"
  spec.add_dependency "sequel", "~> 5.20"
  spec.add_dependency "aws-sdk-s3", "~> 1.56"
  spec.add_dependency "rexml"

  spec.add_development_dependency "bundler", "~> 2.2"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.10"
  spec.add_development_dependency "rspec-core", "~> 3.10"
  spec.add_development_dependency "rspec_junit_formatter", "~> 0.6"
  spec.add_development_dependency "factory_bot", "~> 6.2"
  spec.add_development_dependency "aruba", "~> 1.1.2"
  # last version supporting ruby 2
  spec.add_development_dependency "contracts", "~> 0.16.1"
  spec.add_development_dependency "rubocop", '~> 1.49.0'
  spec.add_development_dependency "rubocop-rspec", '~> 2.19.0'
  spec.add_development_dependency "rubocop-performance", '~> 1.3'
  spec.add_development_dependency "rubocop-sequel", '~> 0.3.4'
  spec.add_development_dependency "amalgalite", "~> 1.6"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
