require 'spec_helper'
require 'longleaf/web/job_registry'

describe Longleaf::Web::JobRegistry do
  subject(:registry) { described_class.new }

  describe '#register' do
    it 'returns a UUID string' do
      id = registry.register
      expect(id).to match(/\A[0-9a-f-]{36}\z/)
    end

    it 'returns a unique id on each call' do
      ids = Array.new(5) { registry.register }
      expect(ids.uniq.length).to eq 5
    end

    it 'stores the job with status :running' do
      id = registry.register
      expect(registry.find(id)[:status]).to eq :running
    end

    it 'stores the provided params' do
      id = registry.register(file: '/some/path', force: true)
      expect(registry.find(id)[:params]).to eq(file: '/some/path', force: true)
    end

    it 'records a started_at timestamp' do
      before = Time.now
      id = registry.register
      after = Time.now
      expect(registry.find(id)[:started_at]).to be_between(before, after)
    end

    it 'leaves completed_at as nil' do
      id = registry.register
      expect(registry.find(id)[:completed_at]).to be_nil
    end

    it 'prunes expired finished jobs on registration' do
      stub_const("#{described_class}::JOB_TTL", 0)
      old_id = registry.register
      registry.complete(old_id)
      sleep 0.01 # ensure completed_at is in the past relative to cutoff

      registry.register
      expect(registry.find(old_id)).to be_nil
    end

    it 'does not prune still-running jobs regardless of age' do
      stub_const("#{described_class}::JOB_TTL", 0)
      running_id = registry.register
      sleep 0.01

      registry.register
      expect(registry.find(running_id)).not_to be_nil
    end
  end

  describe '#complete' do
    it 'transitions the job to :complete' do
      id = registry.register
      registry.complete(id)
      expect(registry.find(id)[:status]).to eq :complete
    end

    it 'sets completed_at' do
      id = registry.register
      before = Time.now
      registry.complete(id)
      after = Time.now
      expect(registry.find(id)[:completed_at]).to be_between(before, after)
    end

    it 'is a no-op for unknown ids' do
      expect { registry.complete('nonexistent') }.not_to raise_error
    end
  end

  describe '#fail' do
    it 'transitions the job to :failed' do
      id = registry.register
      registry.fail(id)
      expect(registry.find(id)[:status]).to eq :failed
    end

    it 'sets completed_at' do
      id = registry.register
      before = Time.now
      registry.fail(id)
      after = Time.now
      expect(registry.find(id)[:completed_at]).to be_between(before, after)
    end

    it 'is a no-op for unknown ids' do
      expect { registry.fail('nonexistent') }.not_to raise_error
    end
  end

  describe '#find' do
    it 'returns nil for an unknown id' do
      expect(registry.find('does-not-exist')).to be_nil
    end

    it 'returns all expected keys' do
      id = registry.register(location: 'loc1')
      job = registry.find(id)
      expect(job.keys).to include(:id, :status, :params, :started_at, :completed_at)
    end

    it 'returns a copy that does not reflect later mutations' do
      id = registry.register
      snapshot = registry.find(id)
      registry.complete(id)
      expect(snapshot[:status]).to eq :running
    end
  end
end