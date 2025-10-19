# frozen_string_literal: true

require 'time'

# AppLogger is a simple thread-safe logger for application logging.
class AppLogger
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

  def info(message) = log(message, 'INFO')
  def error(message) = log(message, 'ERROR')
  def warn(message) = log(message, 'WARN')
  def debug(message) = log(message, 'DEBUG')
end
