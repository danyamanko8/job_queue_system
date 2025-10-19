# frozen_string_literal: true

require 'redis'
require_relative 'job'
require_relative 'app_logger'

# JobQueue manages job enqueueing, dequeueing, and status tracking using Redis.
class JobQueue
  JOBS_KEY = 'jobs:queue'
  JOB_DATA_KEY_PREFIX = 'job:data:'
  JOB_STATUS_KEY_PREFIX = 'job:status:'
  PROCESSING_JOBS_KEY = 'jobs:processing'
  ACTIVE_TAGS_KEY = 'tags:active'

  def initialize(redis_url = ENV['REDIS_URL'] || 'redis://localhost:6379/0')
    @redis = Redis.new(url: redis_url)
    @logger = AppLogger.new
  end

  def enqueue(job)
    raise ArgumentError, 'Job must be a Job instance' unless job.is_a?(Job)

    job_json = job.to_json
    @redis.rpush(JOBS_KEY, job.id)
    @redis.set("#{JOB_DATA_KEY_PREFIX}#{job.id}", job_json)
    @logger.log("Job enqueued: #{job.id} with tags #{job.tags}")
    job
  end

  def dequeue
    job_id = @redis.lpop(JOBS_KEY)
    return nil unless job_id

    job_data = @redis.get("#{JOB_DATA_KEY_PREFIX}#{job_id}")
    return nil unless job_data

    Job.from_json(job_data)
  end

  def peek
    job_id = @redis.lindex(JOBS_KEY, 0)
    return nil unless job_id

    job_data = @redis.get("#{JOB_DATA_KEY_PREFIX}#{job_id}")
    return nil unless job_data

    Job.from_json(job_data)
  end

  def mark_processing(job)
    job.mark_processing
    @redis.sadd(PROCESSING_JOBS_KEY, job.id)
    job.tags.each { |tag| @redis.sadd(ACTIVE_TAGS_KEY, tag) }
    update_job(job)
    @logger.log("Job started processing: #{job.id}")
  end

  def mark_completed(job)
    job.mark_completed
    @redis.srem(PROCESSING_JOBS_KEY, job.id)
    update_job(job)
    cleanup_tags
    @logger.log("Job completed: #{job.id}")
  end

  def mark_failed(job, error_message)
    job.mark_failed(error_message)
    @redis.srem(PROCESSING_JOBS_KEY, job.id)
    update_job(job)
    cleanup_tags
    @logger.log("Job failed: #{job.id} - #{error_message}")
  end

  def update_job(job)
    @redis.set("#{JOB_DATA_KEY_PREFIX}#{job.id}", job.to_json)
  end

  def get_job(job_id)
    job_data = @redis.get("#{JOB_DATA_KEY_PREFIX}#{job_id}")
    return nil unless job_data

    Job.from_json(job_data)
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
    job_ids = @redis.lrange(JOBS_KEY, 0, -1)
    job_ids.map do |id|
      job_data = @redis.get("#{JOB_DATA_KEY_PREFIX}#{id}")
      Job.from_json(job_data) if job_data
    end.compact
  end

  def cleanup_tags
    processing_ids = @redis.smembers(PROCESSING_JOBS_KEY)
    all_tags = Set.new

    processing_ids.each do |job_id|
      job_data = @redis.get("#{JOB_DATA_KEY_PREFIX}#{job_id}")
      if job_data
        job = Job.from_json(job_data)
        job.tags.each { |tag| all_tags.add(tag) }
      end
    end

    current_tags = @redis.smembers(ACTIVE_TAGS_KEY)
    (current_tags - all_tags.to_a).each do |tag|
      @redis.srem(ACTIVE_TAGS_KEY, tag)
    end
  end

  def close
    @redis.close
  end
end
