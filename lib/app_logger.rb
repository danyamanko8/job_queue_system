# frozen_string_literal: true

require 'time'

# AppLogger is a simple thread-safe logger for application logging.
class AppLogger
  LEVELS = {
    debug: 'DEBUG',
    info: 'INFO',
    warn: 'WARN',
    error: 'ERROR'
  }.freeze

  def initialize(output = $stdout)
    @output = output
    @mutex = Mutex.new
  end

  def log(message, level = 'INFO')
    @mutex.synchronize do
      timestamp = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      @output.puts "[#{timestamp}] [#{level}] #{message}"
      @output.flush
    end
  end

  LEVELS.each do |method_name, level|
    define_method(method_name) do |message|
      log(message, level)
    end
  end
end
