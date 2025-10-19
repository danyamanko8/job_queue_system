# frozen_string_literal: true

require 'concurrent'
require 'timeout'
require_relative 'job_queue'
require_relative 'app_logger'

# Worker processes jobs from the queue with multi-threading support
class Worker
  def initialize(worker_id, max_threads: 2, allowed_tags: nil, poll_interval: 1)
    @worker_id = worker_id
    @max_threads = max_threads
    @allowed_tags = allowed_tags ? Set.new(allowed_tags) : nil
    @poll_interval = poll_interval
    @queue = JobQueue.new
    @logger = AppLogger.new
    @running = true
    @paused = false
    @shutting_down = false

    @executor = Concurrent::ThreadPoolExecutor.new(
      min_threads: 1,
      max_threads: max_threads,
      max_queue: max_threads * 2,
      fallback_policy: :abort
    )

    @futures = Set.new
    setup_signal_handlers
  end

  def start
    log_startup_info
    process_jobs_loop
    graceful_shutdown
  rescue StandardError => e
    @logger.error("Worker error: #{e.message}")
    graceful_shutdown
  end

  private

  def log_startup_info
    @logger.info("Worker #{@worker_id} started with #{@max_threads} threads")
    return unless @allowed_tags

    @logger.info("Allowed tags: #{@allowed_tags.to_a.join(', ')}")
  end

  def process_jobs_loop
    loop do
      break if shutdown_complete?

      spawn_job if should_accept_jobs?
      sleep(@poll_interval)
      cleanup_completed_futures
    end
  end

  def shutdown_complete?
    @shutting_down && @futures.empty?
  end

  def should_accept_jobs?
    @running && !@paused && !@shutting_down
  end

  def spawn_job
    return if @futures.size >= @max_threads

    job = find_available_job
    return unless job

    future = Concurrent::Future.execute(executor: @executor) do
      execute_job(job)
    end

    @futures.add(future)
  end

  def find_available_job
    loop do
      job = @queue.peek
      return unless job

      return dequeue_if_matches_tags(job) if allowed_tags_match?(job)

      if job_tags_active?(job)
        AppLogger.new.info("Job #{job.id} is delayed due to active tags")
        return
      end

      taken_job = @queue.dequeue
      @logger.info("Worker #{@worker_id} claimed job #{taken_job&.id}")
      return taken_job
    end
  end

  def allowed_tags_match?(job)
    @allowed_tags && (job.tags.to_set & @allowed_tags).none?
  end

  def dequeue_if_matches_tags(_job)
    @queue.dequeue
    nil
  end

  def job_tags_active?(job)
    active_tags = @queue.active_tags.to_set
    (job.tags.to_set & active_tags).any?
  end

  def job_being_processed?(job)
    processing = @queue.processing_jobs
    processing.include?(job.id)
  end

  def execute_job(job)
    @queue.mark_processing(job)
    @logger.info("Worker #{@worker_id} executing job #{job.id} with tags: #{job.tags.join(', ')}")

    sleep(rand(20..30))

    @queue.mark_completed(job)
    @logger.info("Worker #{@worker_id} completed job #{job.id} with tags: #{job.tags.join(', ')}")
  rescue StandardError => e
    @queue.mark_failed(job, e.message)
    @logger.error("Job #{job.id} failed: #{e.message}")
  end

  def cleanup_completed_futures
    @futures.delete_if(&:rejected?)
    @futures.delete_if { |f| f.fulfilled? || f.rejected? }
  end

  def setup_signal_handlers
    Signal.trap('SIGTERM') { @shutting_down = true }
    Signal.trap('SIGINT') { @shutting_down = true }
    Signal.trap('SIGTSTP') { @paused = true }
    Signal.trap('SIGUSR2') { @paused = false }
  end

  def graceful_shutdown
    @running = false
    log_shutdown_initiation
    wait_for_active_jobs
    shutdown_executor
    log_shutdown_complete
    @queue.close
  end

  def log_shutdown_initiation
    return unless @shutting_down

    @logger.warn('Received shutdown signal, graceful shutdown initiated')
  end

  def wait_for_active_jobs
    @logger.info("Waiting for #{@futures.size} active jobs to complete...")

    timeout_sec = 60
    Timeout.timeout(timeout_sec) do
      @futures.each(&:value!)
    end
  rescue Timeout::Error
    @logger.warn("Timeout waiting for jobs after #{timeout_sec}s")
  end

  def shutdown_executor
    @executor.shutdown
    @executor.wait_for_termination(timeout: 30)
    @logger.info('Thread pool executor shutdown complete')
  end

  def log_shutdown_complete
    @logger.info("Worker #{@worker_id} shutdown complete")
  end
end
