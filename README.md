# Job Queue System (Sidekiq-like)

A simplified job execution system built in Ruby without Rails.

## Features

* ✅ Redis-based job queue
* ✅ Multithreaded workers for parallel execution
* ✅ Tag system for job classification and synchronization
* ✅ Prevention of concurrent execution of jobs with overlapping tags
* ✅ CLI for job management
* ✅ REST API for job creation and status retrieval
* ✅ Signal handling (SIGTERM, SIGINT, SIGTSTP, SIGUSR2)
* ✅ Full operation logging
* ✅ Docker Compose for easy deployment
* ✅ Comprehensive unit tests with MockRedis

## Requirements

- Ruby 3.3.4
- Redis 7.0+
- Docker & Docker Compose (optional)

## Quick Start

```bash
# Clone and setup
git clone <repo>
cd job_queue_system
bundle install

# Option 1: Run with Docker (recommended)
docker compose up --build

# Option 2: Run locally
redis-server &
ruby api.rb &
ruby worker.rb &

# Create a job
ruby cli.rb add --tags payment

# View jobs
curl http://localhost:4567/jobs
```

## Project Structure

```
job_queue_system/
├── lib/
│   ├── job.rb              # Job model with status management
│   ├── job_queue.rb        # Redis-based queue operations
│   ├── worker.rb           # Multi-threaded job processor
│   ├── app_logger.rb       # Logging utility
│   ├── cli.rb              # Command-line interface
│   └── api_server.rb       # Sinatra REST API
├── spec/
│   ├── spec_helper.rb
│   ├── support/
│   │   └── mock_redis.rb
│   └── lib/
│       ├── job_spec.rb
│       ├── job_queue_spec.rb
│       ├── worker_spec.rb
│       └── api_server_spec.rb
├── Gemfile
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Redis (Central Queue)           │
│  - jobs:queue (FIFO queue)              │
│  - job:data:* (Job data)                │
│  - jobs:processing (Active jobs)        │
│  - tags:active (Processing tags)        │
└─────────────────────────────────────────┘
         ↑                    ↑
    ┌────┴────┐          ┌────┴────┐
    │          │          │          │
┌───▼───┐  ┌──▼───┐  ┌──▼───┐  ┌──▼───┐
│Worker1│  │Worker2│  │Worker3│  │Worker4│
│ (2 threads) │ (2 threads) │ (2 threads) │ (2 threads) │
└────────┘  └───────┘  └───────┘  └───────┘
```

## Run locally

### Install dependencies

```bash
bundle install
```

### Start Redis

```bash
redis-server
```

### Start components

```bash
# Terminal 1: API
ruby api.rb

# Terminal 2: Worker 1
ruby worker.rb

# Terminal 3: Worker 2 (with tag filtering)
WORKER_TAGS=hotel,flight ruby worker.rb

# Terminal 4: CLI to create jobs
ruby cli.rb add --tags hotel,flight
```

## CLI Commands

### Create a job

```bash
ruby cli.rb add --tags hotel,flight
ruby cli.rb add --tags payment --data '{"amount": 100}'
```

### List jobs

```bash
ruby cli.rb list
```

### Get job status

```bash
ruby cli.rb status <job-id>
```

## API Endpoints

### Create a job

```bash
curl -X POST http://localhost:4567/jobs \
  -H "Content-Type: application/json" \
  -d '{"tags": ["hotel", "flight"]}'
```

### Get a job

```bash
curl http://localhost:4567/jobs/<job-id>
```

### List all jobs

```bash
curl http://localhost:4567/jobs
```

### Queue statistics

```bash
curl http://localhost:4567/stats
```

### Health check

```bash
curl http://localhost:4567/health
```

## Environment Variables

```
REDIS_URL=redis://localhost:6379/0
API_PORT=4567
WORKER_ID=worker-1
MAX_THREADS=2
POLL_INTERVAL=1
WORKER_TAGS=tag1,tag2
```

## Signal Handling

* **SIGTERM/SIGINT**: Graceful shutdown, completes active jobs
* **SIGTSTP**: Pause accepting new jobs
* **SIGUSR2**: Resume after pause

## Key Constraints

1. **No duplicate execution** - Same job cannot run on multiple workers simultaneously
2. **Tag conflicts** - Jobs with overlapping tags cannot execute in parallel
3. **FIFO ordering** - Jobs execute in creation order (when no conflicts)
4. **Graceful shutdown** - Active jobs complete before worker stops
5. **Worker filtering** - Optional tag-based filtering per worker

## Testing

### Run all tests

```bash
bundle exec rspec
```

### Run specific test file

```bash
bundle exec rspec spec/lib/job_spec.rb
bundle exec rspec spec/lib/job_queue_spec.rb
bundle exec rspec spec/lib/worker_spec.rb
bundle exec rspec spec/lib/api_server_spec.rb
```

### Run with detailed output

```bash
bundle exec rspec -f d
```

### Watch mode

```bash
bundle exec guard
```

### Test structure

```
spec/
├── spec_helper.rb           # RSpec configuration
├── support/
│   └── mock_redis.rb        # In-memory Redis mock
└── lib/
    ├── job_spec.rb
    ├── job_queue_spec.rb
    ├── worker_spec.rb
    └── api_server_spec.rb
```

### Key testing principles

- Tests use MockRedis (no external dependencies)
- Fast execution (no I/O delays)
- Isolated (each test is independent)
- Unit tests focus on single responsibility
- No reliance on real Redis, database, or network calls

## Test Coverage

The project includes comprehensive unit tests:

- **Job tests** - Job model, status transitions, serialization
- **JobQueue tests** - FIFO ordering, tag management, job state tracking
- **Worker tests** - Tag filtering logic, tag conflict detection
- **API tests** - Endpoint validation, error handling

## Scaling

### Local scaling

```bash
# Start multiple workers
ruby worker.rb &
ruby worker.rb &
WORKER_TAGS=hotel ruby worker.rb &
```

### Docker scaling

```bash
# Start with 5 generic workers
docker compose up --scale worker=5 -d

# Add specialized workers
docker compose up --scale worker_hotel=3 -d
```

### Multi-server deployment

Set `REDIS_URL` to point to central Redis instance:

```bash
# Server 1
REDIS_URL=redis://redis-master:6379/0 ruby worker.rb

# Server 2
REDIS_URL=redis://redis-master:6379/0 ruby worker.rb

# Server N
REDIS_URL=redis://redis-master:6379/0 ruby worker.rb
```

## Docker Compose

### Run with Docker

```bash
docker compose up --build
```

### Services

- **redis** - Central message queue and state storage
- **api** - REST API service (port 4567)
- **worker** - Generic job processors (scalable)
- **worker_hotel** - Specialized workers for hotel/flight tags

### Scale workers

```bash
docker compose up -d --scale worker=10
```

### View logs

```bash
docker compose logs -f worker
docker compose logs -f api
```

### Stop all services

```bash
docker compose down
```

## Example Workflow

```bash
# Create jobs with different tags
curl -X POST http://localhost:4567/jobs \
  -H "Content-Type: application/json" \
  -d '{"tags": ["hotel", "booking"]}'

curl -X POST http://localhost:4567/jobs \
  -H "Content-Type: application/json" \
  -d '{"tags": ["payment"]}'

curl -X POST http://localhost:4567/jobs \
  -H "Content-Type: application/json" \
  -d '{"tags": ["hotel", "payment"]}'

# View statistics
curl http://localhost:4567/stats

# Get specific job
curl http://localhost:4567/jobs/{job-id}

# List all jobs
curl http://localhost:4567/jobs
```

## Performance

- Job processing: 0-3 seconds per job
- Redis operations: < 1ms
- Worker startup: < 1 second
- Test execution: < 1 second (all tests)

## Development

```bash
# Install development dependencies
bundle install

# Run tests
bundle exec rspec

# Code quality check
bundle exec rubocop lib/

# Fix code style
bundle exec rubocop -A lib/
```
