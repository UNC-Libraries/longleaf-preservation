require 'spec_helper'
require 'aruba/rspec'
require 'longleaf/version'

describe 'cli general commands', :type => :aruba do
  context 'with --version' do
    before do
      run_command_and_stop("longleaf --version", fail_on_error: false)
    end

    it 'outputs the current version of longleaf' do
      expect(last_command_started).to have_output(/longleaf version #{Longleaf::VERSION}/)
      expect(last_command_started).to have_exit_status(0)
    end
  end

  context 'with no commmand' do
    before do
      run_command_and_stop("longleaf", fail_on_error: false)
    end

    it 'outputs help text' do
      expect(last_command_started).to have_output(/Commands:\n.*longleaf --version/)
      expect(last_command_started).to have_exit_status(0)
    end
  end

  context 'with help commmand' do
    before do
      run_command_and_stop("longleaf help", fail_on_error: false)
    end

    it do
      expect(last_command_started).to have_output(/Commands:\n.*longleaf --version/)
      expect(last_command_started).to have_exit_status(0)
    end
  end
end
