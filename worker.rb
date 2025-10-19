# frozen_string_literal: true

require_relative 'lib/worker'

worker_id = ENV['WORKER_ID'] || "worker-#{Process.pid}"
max_threads = (ENV['MAX_THREADS'] || 2).to_i
poll_interval = (ENV['POLL_INTERVAL'] || 1).to_i

allowed_tags = ENV['WORKER_TAGS']&.split(',')&.map(&:strip)

worker = Worker.new(
  worker_id,
  max_threads:,
  allowed_tags:,
  poll_interval:
)

worker.start
