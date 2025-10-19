# frozen_string_literal: true

require_relative 'job_queue'
require_relative 'job'
require_relative 'app_logger'

# Command-line interface for job queue management
class CLI
  def initialize
    @queue = JobQueue.new
    @logger = AppLogger.new
  end

  def run(args)
    command = args.shift

    case command
    when 'add'
      handle_add(args)
    when 'list'
      handle_list
    when 'status'
      handle_status(args)
    when 'help'
      print_help
    else
      puts "Unknown command: #{command}"
      print_help
    end
  rescue StandardError => e
    @logger.error("CLI error: #{e.message}")
    puts "Error: #{e.message}"
  ensure
    @queue.close
  end

  private

  def handle_add(args)
    tags = []
    data = {}

    i = 0
    while i < args.length
      case args[i]
      when '--tags'
        tags = args[i + 1]&.split(',') || []
        i += 2
      when '--data'
        begin
          data = JSON.parse(args[i + 1]) if args[i + 1]
        rescue JSON::ParseError
          puts 'Invalid JSON data'
        end
        i += 2
      else
        i += 1
      end
    end

    job = Job.new(tags:, data:)
    @queue.enqueue(job)
    puts "Job created: #{job.id}"
    puts "Tags: #{job.tags.join(', ')}" if job.tags.any?
  end

  def handle_list
    jobs = @queue.all_jobs

    if jobs.empty?
      puts 'No jobs in queue'
      return
    end

    puts "\nJobs in queue:"
    puts '-' * 80
    jobs.each do |job|
      puts "ID: #{job.id}"
      puts "  Status: #{job.status}"
      puts "  Tags: #{job.tags.join(', ')}" if job.tags.any?
      puts "  Created: #{job.created_at}"
      puts ''
    end
  end

  def handle_status(args)
    job_id = args.first
    unless job_id
      puts 'Job ID required'
      return
    end

    job = @queue.get_job(job_id)
    if job
      puts "Job: #{job.id}"
      puts "Status: #{job.status}"
      puts "Tags: #{job.tags.join(', ')}" if job.tags.any?
      puts "Created: #{job.created_at}"
      puts "Started: #{job.started_at}" if job.started_at
      puts "Completed: #{job.completed_at}" if job.completed_at
      puts "Error: #{job.error}" if job.error
    else
      puts "Job not found: #{job_id}"
    end
  end

  def print_help
    puts <<~HELP
      Usage: ruby cli.rb COMMAND [OPTIONS]

      Commands:
        add         Create a new job
                    --tags TAG1,TAG2  (comma-separated tags)
                    --data JSON       (optional JSON data)
      #{'  '}
        list        List all jobs in queue
      #{'  '}
        status ID   Get job status
      #{'  '}
        help        Show this help message

      Examples:
        ruby cli.rb add --tags hotel,flight
        ruby cli.rb add --tags payment --data '{"amount": 100}'
        ruby cli.rb list
        ruby cli.rb status <job-id>
    HELP
  end
end
