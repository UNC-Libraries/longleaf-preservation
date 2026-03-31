# Shared examples for API key authentication via the ApiKeyAuth middleware.
#
# The including context must define a `make_request` method that performs a
# single API request without any auth header, e.g.:
#
#   context 'API key authentication' do
#     def make_request
#       post '/api/register', {}.to_json, 'CONTENT_TYPE' => 'application/json'
#     end
#     it_behaves_like 'API key authentication'
#   end
RSpec.shared_examples 'API key authentication' do
  context 'when LONGLEAF_API_KEYS is configured' do
    before { ENV['LONGLEAF_API_KEYS'] = 'test-key-1,test-key-2' }
    after  { ENV.delete('LONGLEAF_API_KEYS') }

    it 'returns 401 with an error body when no API key is provided' do
      make_request
      expect(last_response.status).to eq 401
      expect(JSON.parse(last_response.body)['error']).to eq 'Unauthorized'
    end

    it 'returns 401 when an unrecognized API key is provided' do
      header 'X-Api-Key', 'not-a-valid-key'
      make_request
      expect(last_response.status).to eq 401
    end

    it 'passes the request through when a valid API key is provided' do
      header 'X-Api-Key', 'test-key-2'
      make_request
      expect(last_response.status).not_to eq 401
    end
  end

  context 'when LONGLEAF_API_KEYS is not configured' do
    before { ENV.delete('LONGLEAF_API_KEYS') }

    it 'allows requests without an API key' do
      make_request
      expect(last_response.status).not_to eq 401
    end
  end
end
