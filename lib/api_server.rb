# frozen_string_literal: true

require 'sinatra/base'
require 'json'
require_relative 'job_queue'
require_relative 'job'
require_relative 'app_logger'

class APIServer < Sinatra::Base
  set :port, ENV['API_PORT'] || 4567
  set :bind, '0.0.0.0'
  set :logging, false

  # Налаштування для тестів
  disable :protection if ENV['RACK_ENV'] == 'test'

  def initialize
    super()
    @queue = JobQueue.new
    @logger = AppLogger.new
  end

  before do
    content_type :json
  end

  post '/jobs' do
    body = request.body.read
    params = JSON.parse(body)

    tags = params['tags'] || []
    data = params['data'] || {}

    job = Job.new(tags: Array(tags), data: data)
    @queue.enqueue(job)

    @logger.info("API: Job created #{job.id}")
    status 201
    job.to_json
  rescue JSON::ParserError
    status 400
    { error: 'Invalid JSON' }.to_json
  rescue StandardError => e
    @logger.error("API error: #{e.message}")
    status 500
    { error: e.message }.to_json
  end

  get '/jobs/:id' do
    job = @queue.get_job(params[:id])

    if job
      @logger.info("API: Retrieved job #{params[:id]}")
      job.to_json
    else
      status 404
      { error: 'Job not found' }.to_json
    end
  rescue StandardError => e
    @logger.error("API error: #{e.message}")
    status 500
    { error: e.message }.to_json
  end

  get '/jobs' do
    jobs = @queue.all_jobs
    @logger.info('API: Listed all jobs')
    jobs.map(&:to_h).to_json
  rescue StandardError => e
    @logger.error("API error: #{e.message}")
    status 500
    { error: e.message }.to_json
  end

  get '/stats' do
    {
      queue_size: @queue.queue_size,
      processing: @queue.processing_jobs.length,
      active_tags: @queue.active_tags
    }.to_json
  rescue StandardError => e
    @logger.error("API error: #{e.message}")
    status 500
    { error: e.message }.to_json
  end

  get '/health' do
    { status: 'ok' }.to_json
  end

  not_found do
    status 404
    { error: 'Endpoint not found' }.to_json
  end

  error do
    status 500
    { error: 'Internal server error' }.to_json
  end
end
