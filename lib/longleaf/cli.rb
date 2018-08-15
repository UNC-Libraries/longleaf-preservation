require "thor"

module Longleaf
  class CLI < Thor
    desc "register", "Register files with Longleaf"
    def register()
      puts "Register files"
    end
  end
end