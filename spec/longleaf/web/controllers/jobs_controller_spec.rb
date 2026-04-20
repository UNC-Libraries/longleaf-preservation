require 'spec_helper'
require 'rack/test'
require 'json'
require 'longleaf/web/app'
require 'longleaf/web/job_registry'
require_relative '../../../support/shared_examples/api_key_auth_examples'

describe 'GET /api/jobs/:id' do
  include Rack::Test::Methods

  def app
    Longleaf::Web::App
  end

  let(:registry) { Longleaf::Web::JobRegistry.new }

  before { Longleaf::Web::App.job_registry = registry }

  after do
    Longleaf::Web::App.job_registry = Longleaf::Web::JobRegistry.new
    Longleaf::Web::App.app_manager = nil
  end

  def get_job(id)
    get "/api/jobs/#{id}"
  end

  def response_body
    JSON.parse(last_response.body)
  end

  context 'API key authentication' do
    def make_request
      get '/api/jobs/some-id'
    end

    it_behaves_like 'API key authentication'
  end

  context 'when the job id is not found' do
    it 'returns 404' do
      get_job('nonexistent-id')
      expect(last_response.status).to eq 404
    end

    it 'returns an error body' do
      get_job('nonexistent-id')
      expect(response_body['error']).to eq 'Job not found'
    end
  end

  context 'when the job is running' do
    let(:job_id) { registry.register(location: 'loc1') }

    it 'returns 200' do
      get_job(job_id)
      expect(last_response.status).to eq 200
    end

    it 'returns status running' do
      get_job(job_id)
      expect(response_body['status']).to eq 'running'
    end

    it 'returns the job id' do
      get_job(job_id)
      expect(response_body['id']).to eq job_id
    end

    it 'returns started_at and nil completed_at' do
      get_job(job_id)
      expect(response_body['started_at']).not_to be_nil
      expect(response_body['completed_at']).to be_nil
    end
  end

  context 'when the job has completed' do
    let(:job_id) do
      id = registry.register
      registry.complete(id)
      id
    end

    it 'returns 200' do
      get_job(job_id)
      expect(last_response.status).to eq 200
    end

    it 'returns status complete' do
      get_job(job_id)
      expect(response_body['status']).to eq 'complete'
    end

    it 'returns a completed_at timestamp' do
      get_job(job_id)
      expect(response_body['completed_at']).not_to be_nil
    end
  end

  context 'when the job has failed' do
    let(:job_id) do
      id = registry.register
      registry.fail(id)
      id
    end

    it 'returns 200' do
      get_job(job_id)
      expect(last_response.status).to eq 200
    end

    it 'returns status failed' do
      get_job(job_id)
      expect(response_body['status']).to eq 'failed'
    end
  end
end