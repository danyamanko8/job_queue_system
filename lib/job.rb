# frozen_string_literal: true

require 'json'
require 'securerandom'

# Job class represents a unit of work with metadata and status tracking.
class Job
  attr_accessor :id, :tags, :status, :created_at, :started_at, :completed_at, :error, :data

  STATUSES = {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }.freeze

  # Dynamically define status check methods (pending?, processing?, etc.)
  STATUSES.each_value do |status|
    define_method("#{status}?") do
      @status == status
    end
  end

  # Dynamically define status setter methods
  STATUSES.each do |key, status|
    define_method("mark_#{key}") do |error_msg = nil|
      @status = status
      @started_at = Time.now if key == :processing
      @completed_at = Time.now if %i[completed failed].include?(key)
      @error = error_msg if key == :failed
    end
  end

  def initialize(tags: [], data: {}, id: nil)
    @id = id || SecureRandom.uuid
    @tags = Array(tags)
    @status = STATUSES[:pending]
    @created_at = Time.now
    @started_at = nil
    @completed_at = nil
    @error = nil
    @data = data
  end

  def to_h
    {
      id: @id,
      tags: @tags,
      status: @status,
      created_at: @created_at.to_s,
      started_at: @started_at&.to_s,
      completed_at: @completed_at&.to_s,
      error: @error,
      data: @data
    }
  end

  def to_json(*args)
    to_h.to_json(*args)
  end

  def self.from_json(json_str)
    data = JSON.parse(json_str)
    job = new(
      tags: data['tags'],
      data: data['data'],
      id: data['id']
    )
    job.status = data['status']
    job.started_at = Time.parse(data['started_at']) if data['started_at']
    job.completed_at = Time.parse(data['completed_at']) if data['completed_at']
    job.error = data['error']
    job
  end
end
