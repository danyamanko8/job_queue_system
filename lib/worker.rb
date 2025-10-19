# frozen_string_literal: true

require 'concurrent'
require 'timeout'
require_relative 'job_queue'
require_relative 'app_logger'

# Worker processes jobs from the queue with multi-threading support
class Worker
  SHUTDOWN_TIMEOUT = 60
  EXECUTOR_TIMEOUT = 30
  DEFAULT_POLL_INTERVAL = 1

  def initialize(worker_id, max_threads: 2, allowed_tags: nil, poll_interval: DEFAULT_POLL_INTERVAL)
    @worker_id = worker_id
    @max_threads = max_threads
    @allowed_tags = allowed_tags ? Set.new(allowed_tags) : nil
    @poll_interval = poll_interval
    @queue = JobQueue.new
    @logger = AppLogger.new
    @running = true
    @paused = false
    @shutting_down = false
    @executor = build_executor(max_threads)
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

  def build_executor(max_threads)
    Concurrent::ThreadPoolExecutor.new(
      min_threads: 1,
      max_threads:,
      max_queue: max_threads * 2,
      fallback_policy: :abort
    )
  end

  def log_startup_info
    @logger.info("Worker #{@worker_id} started with #{@max_threads} threads")
    @logger.info("Allowed tags: #{@allowed_tags.to_a.join(', ')}") if @allowed_tags
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

    future = Concurrent::Future.execute(executor: @executor) { execute_job(job) }
    @futures.add(future)
  end

  def find_available_job
    loop do
      job = @queue.peek
      return unless job

      # Step 1: check allowed tags
      return dequeue_rejected_job if allowed_tags_mismatch?(job)

      # Step 2: is job available?
      return unless job_available?(job)

      # Step 3: check for tag conflicts
      return if job_tags_conflict?(job)

      return @queue.dequeue
    end
  end

  def allowed_tags_mismatch?(job)
    puts "Allowed tags: #{@allowed_tags.to_a.join(', ')}; Job tags: #{job.tags.join(', ')}"
    @allowed_tags && (job.tags.to_set & @allowed_tags).none?
  end

  def job_available?(job)
    !job_being_processed?(job)
  end

  def job_being_processed?(job)
    @queue.processing_jobs.include?(job.id)
  end

  def job_tags_conflict?(job)
    active_tags = @queue.active_tags.to_set
    (job.tags.to_set & active_tags).any?
  end

  def dequeue_rejected_job
    @queue.dequeue
    nil
  end

  def execute_job(job)
    @queue.mark_processing(job)
    @logger.info("Worker #{@worker_id} executing job #{job.id} with tags: #{job.tags.join(', ')}")

    sleep(rand(0..3))

    @queue.mark_completed(job)
    @logger.info("Worker #{@worker_id} completed job #{job.id}")
  rescue StandardError => e
    @queue.mark_failed(job, e.message)
    @logger.error("Job #{job.id} failed: #{e.message}")
  ensure
    cleanup_completed_futures
  end

  def cleanup_completed_futures
    @futures.delete_if { |f| f.rejected? || f.fulfilled? }
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
    @logger.warn('Received shutdown signal, graceful shutdown initiated') if @shutting_down
  end

  def wait_for_active_jobs
    @logger.info("Waiting for #{@futures.size} active jobs to complete...")

    Timeout.timeout(SHUTDOWN_TIMEOUT) { @futures.each(&:value!) }
  rescue Timeout::Error
    @logger.warn("Timeout waiting for jobs after #{SHUTDOWN_TIMEOUT}s")
  end

  def shutdown_executor
    @executor.shutdown
    @executor.wait_for_termination(timeout: EXECUTOR_TIMEOUT)
    @logger.info('Thread pool executor shutdown complete')
  end

  def log_shutdown_complete
    @logger.info("Worker #{@worker_id} shutdown complete")
  end
end
