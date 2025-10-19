# frozen_string_literal: true

require_relative '../../lib/worker'

RSpec.describe Worker do
  let(:worker) { Worker.new('test-worker', max_threads: 2) }

  describe '#initialize' do
    it 'creates worker with correct attributes' do
      expect(worker.instance_variable_get(:@worker_id)).to eq('test-worker')
      expect(worker.instance_variable_get(:@max_threads)).to eq(2)
      expect(worker.instance_variable_get(:@running)).to be true
    end

    it 'accepts allowed_tags parameter' do
      worker_with_tags = Worker.new('test', allowed_tags: %w[hotel flight])
      tags = worker_with_tags.instance_variable_get(:@allowed_tags)
      expect(tags).to include('hotel', 'flight')
    end
  end

  describe 'tag filtering' do
    let(:worker_with_tags) { Worker.new('test', allowed_tags: ['hotel']) }

    it 'filters jobs by allowed tags' do
      job_match = Job.new(tags: %w[hotel booking])
      job_no_match = Job.new(tags: ['payment'])

      expect(worker_with_tags.send(:allowed_tags_mismatch?, job_match)).to be false
      expect(worker_with_tags.send(:allowed_tags_mismatch?, job_no_match)).to be true
    end
  end

  describe 'signal handling' do
    it 'sets shutdown flag on SIGTERM' do
      worker.send(:setup_signal_handlers)
      Process.kill('SIGTERM', Process.pid)
      sleep 0.1
      expect(worker.instance_variable_get(:@shutting_down)).to be true
    end

    it 'sets paused flag on SIGTSTP' do
      worker.send(:setup_signal_handlers)
      Process.kill('SIGTSTP', Process.pid)
      sleep 0.1
      expect(worker.instance_variable_get(:@paused)).to be true
    end

    it 'unsets paused flag on SIGUSR2' do
      worker.instance_variable_set(:@paused, true)
      worker.send(:setup_signal_handlers)
      Process.kill('SIGUSR2', Process.pid)
      sleep 0.1
      expect(worker.instance_variable_get(:@paused)).to be false
    end
  end
end
