# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'longleaf/version'

Gem::Specification.new do |spec|
  spec.name          = "longleaf"
  spec.version       = Longleaf::VERSION
  spec.authors       = ["bbpennel"]
  spec.email         = ["bbpennel@email.unc.edu"]

  spec.summary       = %q{Longleaf preservation services tool}
  spec.description   = %q{Provides a framework for performing preservation services over sets of files.}
  spec.homepage      = "https://github.com/UNC-Libraries/"
  spec.license       = "Apache-2.0"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = "longleaf"
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", "~> 0.20.0"
  spec.add_dependency "yard", "~> 0.9.16"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.6.0"
  spec.add_development_dependency "factory_bot", "~> 4.0"
end
