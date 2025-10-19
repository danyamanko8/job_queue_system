# frozen_string_literal: true

require_relative 'lib/cli'

cli = CLI.new
cli.run(ARGV)
