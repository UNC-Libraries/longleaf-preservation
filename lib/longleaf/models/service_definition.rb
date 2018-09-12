require_relative 'service_fields'

# Definition of a preservation service
module Longleaf
  class ServiceDefinition
    attr_reader :name
    attr_reader :work_script
    attr_reader :frequency, :delay
    attr_reader :properties
    
    def initialize(name:, work_script:, frequency: nil, delay: nil, properties: Hash.new)
      raise ArgumentError.new("Parameters name and work_script are required") unless name && work_script
      
      @properties = properties
      @name = name
      @work_script = work_script
      @frequency = frequency
      @delay = delay
    end
  end
end