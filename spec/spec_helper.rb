# frozen_string_literal: true

ENV['RACK_ENV'] = 'test'

require_relative 'support/mock_redis'
require 'redis'

class Redis
  def self.new(url: nil, **_options)
    MockRedis.new
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.after(:each) do
    require_relative '../lib/job_queue'
    queue = JobQueue.new
    queue.instance_variable_get(:@redis).flushdb
    queue.close
  rescue StandardError
    Logger.new($stdout).warn('Could not flush MockRedis after test')
  end
end
