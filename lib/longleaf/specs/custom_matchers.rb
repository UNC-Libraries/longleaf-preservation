module Longleaf
  # Match if the parameter is a {FileRecord} with the expected path
  RSpec::Matchers.define :be_file_record_for do |expected|
    match do |actual|
      return false if actual.nil? || !actual.is_a?(Longleaf::FileRecord)
      actual.path == expected
    end
  end
end
