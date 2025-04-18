#!/bin/bash

# Build the Docker image if it doesn't exist
if ! docker image inspect elixir-arm64:latest &> /dev/null; then
  echo "Building Docker image..."
  ./docker/build-docker-image.sh
fi

# Start PostgreSQL and the app container
echo "Starting services..."
docker-compose up -d

# Wait for PostgreSQL to be fully available
echo "Waiting for PostgreSQL to be ready..."
docker-compose exec elixir bash -c 'until pg_isready -h postgres -U postgres; do sleep 1; done'

# Run mix deps.get and compile
echo "Installing dependencies..."
docker-compose exec elixir mix deps.get
docker-compose exec elixir mix deps.compile

# Run the tests
echo "Running tests..."
docker-compose exec elixir mix test "$@"

# Execution complete
echo "Test execution complete!"
