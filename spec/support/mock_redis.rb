# frozen_string_literal: true

class MockRedis
  def initialize(url: nil, **_options)
    @data = {}
    @lists = {}
    @sets = {}
  end

  # List operations
  def rpush(key, value)
    @lists[key] ||= []
    @lists[key].push(value)
    @lists[key].length
  end

  def lpop(key)
    @lists[key] ||= []
    @lists[key].shift
  end

  def lindex(key, index)
    @lists[key] ||= []
    @lists[key][index]
  end

  def lrange(key, start, stop)
    @lists[key] ||= []
    stop = @lists[key].length - 1 if stop == -1
    @lists[key][start..stop] || []
  end

  def llen(key)
    @lists[key] ||= []
    @lists[key].length
  end

  # String operations
  def set(key, value)
    @data[key] = value
  end

  def get(key)
    @data[key]
  end

  # Set operations
  def sadd(key, value)
    @sets[key] ||= Set.new
    @sets[key].add(value)
  end

  def srem(key, value)
    @sets[key] ||= Set.new
    @sets[key].delete(value)
  end

  def smembers(key)
    @sets[key] ||= Set.new
    @sets[key].to_a
  end

  def sismember(key, value)
    @sets[key] ||= Set.new
    @sets[key].include?(value)
  end

  # Utility
  def flushdb
    @data.clear
    @lists.clear
    @sets.clear
  end

  def close
    # no-op
  end
end
