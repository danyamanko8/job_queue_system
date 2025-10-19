# frozen_string_literal: true

require_relative '../../lib/job'

RSpec.describe Job do
  describe '#initialize' do
    it 'creates a job with default values' do
      job = Job.new
      expect(job.id).not_to be_nil
      expect(job.status).to eq('pending')
      expect(job.tags).to eq([])
      expect(job.created_at).to be_a(Time)
    end

    it 'creates a job with custom tags and data' do
      job = Job.new(tags: %w[tag1 tag2], data: { key: 'value' })
      expect(job.tags).to eq(%w[tag1 tag2])
      expect(job.data).to eq({ key: 'value' })
    end
  end

  describe 'status predicate methods' do
    let(:job) { Job.new }

    it 'responds to pending?' do
      expect(job.pending?).to be true
    end

    it 'responds to processing?' do
      job.mark_processing
      expect(job.processing?).to be true
    end

    it 'responds to completed?' do
      job.mark_completed
      expect(job.completed?).to be true
    end

    it 'responds to failed?' do
      job.mark_failed('error')
      expect(job.failed?).to be true
    end
  end

  describe 'status transitions' do
    let(:job) { Job.new }

    it 'transitions from pending to processing' do
      expect(job.pending?).to be true
      job.mark_processing
      expect(job.processing?).to be true
      expect(job.started_at).not_to be_nil
    end

    it 'transitions from processing to completed' do
      job.mark_processing
      job.mark_completed
      expect(job.completed?).to be true
      expect(job.completed_at).not_to be_nil
    end

    it 'transitions from processing to failed' do
      job.mark_processing
      job.mark_failed('Connection timeout')
      expect(job.failed?).to be true
      expect(job.error).to eq('Connection timeout')
    end
  end

  describe '#to_h' do
    it 'converts job to hash with all fields' do
      job = Job.new(tags: ['test'])
      hash = job.to_h
      expect(hash).to include(:id, :tags, :status, :created_at, :data)
    end
  end

  describe '#to_json' do
    it 'converts job to valid JSON' do
      job = Job.new(tags: ['test'])
      json = job.to_json
      parsed = JSON.parse(json)
      expect(parsed).to be_a(Hash)
      expect(parsed['id']).to eq(job.id)
    end
  end

  describe '.from_json' do
    it 'restores job from JSON' do
      original = Job.new(tags: %w[test hotel], data: { amount: 100 })
      json = original.to_json
      restored = Job.from_json(json)

      expect(restored.id).to eq(original.id)
      expect(restored.tags).to eq(original.tags)
      expect(restored.status).to eq(original.status)
    end

    it 'preserves status changes after serialization' do
      original = Job.new(tags: ['test'])
      original.mark_processing
      original.mark_completed

      json = original.to_json
      restored = Job.from_json(json)

      expect(restored.completed?).to be true
      expect(restored.completed_at).not_to be_nil
    end
  end
end
