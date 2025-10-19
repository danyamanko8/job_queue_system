# frozen_string_literal: true

require 'rack/test'
require_relative '../../lib/api_server'

RSpec.describe APIServer do
  include Rack::Test::Methods

  def app
    APIServer.new
  end

  describe 'POST /jobs' do
    it 'creates a new job' do
      post '/jobs', { tags: ['test'] }.to_json, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(201)
      body = JSON.parse(last_response.body)
      expect(body).to have_key('id')
      expect(body['tags']).to eq(['test'])
      expect(body['status']).to eq('pending')
    end

    it 'returns 400 for invalid JSON' do
      post '/jobs', 'invalid json', { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
    end
  end

  describe 'GET /jobs/:id' do
    it 'returns job by id' do
      post '/jobs', { tags: ['test'] }.to_json, { 'CONTENT_TYPE' => 'application/json' }
      job_id = JSON.parse(last_response.body)['id']

      get "/jobs/#{job_id}"
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['id']).to eq(job_id)
    end

    it 'returns 404 for non-existent job' do
      get '/jobs/non-existent-id'
      expect(last_response.status).to eq(404)
    end
  end

  describe 'GET /health' do
    it 'returns ok status' do
      get '/health'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['status']).to eq('ok')
    end
  end

  describe 'GET /stats' do
    it 'returns queue statistics' do
      get '/stats'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body).to have_key('queue_size')
      expect(body).to have_key('processing')
      expect(body).to have_key('active_tags')
    end
  end
end
