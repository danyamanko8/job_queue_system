# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.3.4'

# Core dependencies
gem 'json', '~> 2.6'
gem 'redis', '~> 5.1'
gem 'sinatra', '~> 3.1'
gem 'concurrent-ruby', '~> 1.2'

# Web server
gem 'puma', '~> 6.4'
gem 'rackup', '~> 1.0'

# Configuration
gem 'dotenv', '~> 2.8'

# Development
group :development do
  gem 'rubocop', '~> 1.63', require: false
  gem 'rubocop-performance', '~> 1.21', require: false
  gem 'rubocop-rake', '~> 0.6', require: false
end

# Testing
group :test do
  gem 'rspec', '~> 3.13'
  gem 'rspec-mocks', '~> 3.13'
  gem 'rack-test', '~> 1.1'
  gem 'fakeredis'
end
