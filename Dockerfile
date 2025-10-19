FROM ruby:3.3.4

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy Gemfile
COPY Gemfile Gemfile.lock* ./

# Install gems
RUN bundle install

# Copy application
COPY . .

# Make scripts executable
RUN chmod +x cli.rb worker.rb api.rb

CMD ["ruby", "worker.rb"]