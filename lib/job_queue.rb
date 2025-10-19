# frozen_string_literal: true

require 'redis'
require_relative 'job'
require_relative 'app_logger'

# JobQueue manages job enqueueing, dequeueing, and status tracking using Redis.
class JobQueue
  JOBS_KEY = 'jobs:queue'
  JOB_DATA_KEY_PREFIX = 'job:data:'
  PROCESSING_JOBS_KEY = 'jobs:processing'
  ACTIVE_TAGS_KEY = 'tags:active'

  def initialize(redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0')
    @redis = Redis.new(url: redis_url)
    @logger = AppLogger.new
  end

  def enqueue(job)
    raise ArgumentError, 'Job must be a Job instance' unless job.is_a?(Job)

    save_job(job)
    @redis.rpush(JOBS_KEY, job.id)
    @logger.log("Job enqueued: #{job.id} with tags #{job.tags}")
    job
  end

  def dequeue
    job_id = @redis.lpop(JOBS_KEY)
    return unless job_id

    fetch_job(job_id)
  end

  def peek
    job_id = @redis.lindex(JOBS_KEY, 0)
    return unless job_id

    fetch_job(job_id)
  end

  def mark_processing(job)
    job.mark_processing
    @redis.sadd(PROCESSING_JOBS_KEY, job.id)
    job.tags.each { |tag| @redis.sadd(ACTIVE_TAGS_KEY, tag) }
    save_job(job)
    @logger.log("Job started processing: #{job.id}")
  end

  def mark_completed(job)
    update_job_status(job) { job.mark_completed }
    @logger.log("Job completed: #{job.id}")
  end

  def mark_failed(job, error_message)
    update_job_status(job) { job.mark_failed(error_message) }
    @logger.log("Job failed: #{job.id} - #{error_message}")
  end

  def get_job(job_id)
    fetch_job(job_id)
  end

  def active_tags
    @redis.smembers(ACTIVE_TAGS_KEY)
  end

  def processing_jobs
    @redis.smembers(PROCESSING_JOBS_KEY)
  end

  def queue_size
    @redis.llen(JOBS_KEY)
  end

  def all_jobs
    @redis.lrange(JOBS_KEY, 0, -1).filter_map { |id| fetch_job(id) }
  end

  def close
    @redis.close
  end

  private

  def fetch_job(job_id)
    job_data = @redis.get(job_key(job_id))
    Job.from_json(job_data) if job_data
  end

  def save_job(job)
    @redis.set(job_key(job.id), job.to_json)
  end

  def job_key(job_id)
    "#{JOB_DATA_KEY_PREFIX}#{job_id}"
  end

  def update_job_status(job)
    yield
    @redis.srem(PROCESSING_JOBS_KEY, job.id)
    save_job(job)
    cleanup_tags
  end

  def cleanup_tags
    processing_ids = @redis.smembers(PROCESSING_JOBS_KEY)
    active_job_tags = processing_ids.each_with_object(Set.new) do |job_id, tags|
      job = fetch_job(job_id)
      job&.tags&.each { |tag| tags.add(tag) }
    end

    current_tags = @redis.smembers(ACTIVE_TAGS_KEY)
    (current_tags - active_job_tags.to_a).each do |tag|
      @redis.srem(ACTIVE_TAGS_KEY, tag)
    end
  end
end
