require 'spec_helper'
require 'rack/test'
require 'json'
require 'longleaf/web/app'
require_relative '../support/shared_examples/api_key_auth_examples'

describe 'GET /api/healthcheck' do
  include Rack::Test::Methods

  def app
    Longleaf::Web::App
  end

  after do
    Longleaf::Web::App.app_manager = nil
  end

  def response_body
    JSON.parse(last_response.body)
  end

  context 'API key authentication' do
    def make_request
      get '/api/healthcheck'
    end

    it_behaves_like 'API key authentication'
  end

  context 'when application configuration is not loaded' do
    before { Longleaf::Web::App.app_manager = nil }

    it 'returns 503 with an unavailable status' do
      get '/api/healthcheck'

      expect(last_response.status).to eq 503
      expect(response_body).to eq('status' => 'unavailable')
    end
  end

  context 'when application configuration is loaded' do
    before { Longleaf::Web::App.app_manager = Object.new }

    it 'returns 200 with an ok status' do
      get '/api/healthcheck'

      expect(last_response.status).to eq 200
      expect(response_body).to eq('status' => 'ok')
    end
  end
end
