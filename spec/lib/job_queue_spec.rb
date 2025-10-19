# frozen_string_literal: true

require_relative '../../lib/job_queue'
require_relative '../../lib/job'

RSpec.describe JobQueue do
  let(:queue) { JobQueue.new }

  after do
    queue.close
  end

  describe '#enqueue' do
    it 'adds job to queue' do
      job = Job.new(tags: ['test'])
      queue.enqueue(job)

      expect(queue.queue_size).to eq(1)
    end

    it 'raises error for non-Job objects' do
      expect { queue.enqueue('not a job') }.to raise_error(ArgumentError)
    end
  end

  describe '#dequeue' do
    it 'removes and returns job from queue' do
      job1 = Job.new(tags: ['test1'])
      job2 = Job.new(tags: ['test2'])

      queue.enqueue(job1)
      queue.enqueue(job2)

      dequeued = queue.dequeue
      expect(dequeued.id).to eq(job1.id)
      expect(queue.queue_size).to eq(1)
    end

    it 'returns nil for empty queue' do
      expect(queue.dequeue).to be_nil
    end
  end

  describe '#peek' do
    it 'returns job without removing it' do
      job = Job.new(tags: ['test'])
      queue.enqueue(job)

      peeked = queue.peek
      expect(peeked.id).to eq(job.id)
      expect(queue.queue_size).to eq(1)
    end
  end

  describe '#mark_processing' do
    it 'adds job to processing set' do
      job = Job.new(tags: ['test'])
      queue.enqueue(job)
      job = queue.dequeue

      queue.mark_processing(job)
      expect(queue.processing_jobs).to include(job.id)
    end

    it 'adds tags to active tags' do
      job = Job.new(tags: %w[hotel booking])
      queue.enqueue(job)
      job = queue.dequeue

      queue.mark_processing(job)
      active = queue.active_tags
      expect(active).to include('hotel', 'booking')
    end
  end

  describe '#mark_completed' do
    it 'removes job from processing' do
      job = Job.new(tags: ['test'])
      queue.enqueue(job)
      job = queue.dequeue
      queue.mark_processing(job)

      queue.mark_completed(job)
      expect(queue.processing_jobs).not_to include(job.id)
    end

    it 'cleans up tags' do
      job = Job.new(tags: ['hotel'])
      queue.enqueue(job)
      job = queue.dequeue
      queue.mark_processing(job)

      queue.mark_completed(job)
      expect(queue.active_tags).not_to include('hotel')
    end
  end

  describe 'tag conflict detection' do
    it 'prevents jobs with overlapping tags from processing' do
      job1 = Job.new(tags: %w[hotel booking])
      job2 = Job.new(tags: %w[hotel payment])

      queue.enqueue(job1)
      queue.enqueue(job2)

      taken1 = queue.dequeue
      queue.mark_processing(taken1)

      active = queue.active_tags
      expect(active).to include('hotel', 'booking')

      # job2 має 'hotel' що в active - конфлікт!
      job2_from_db = Job.from_json(queue.get_job(job2.id).to_json)
      has_conflict = (job2_from_db.tags.to_set & active.to_set).any?
      expect(has_conflict).to be true
    end
  end
end
