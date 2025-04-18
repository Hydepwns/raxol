#!/bin/bash

# Set image name and tag
IMAGE_NAME="elixir-arm64"
TAG="latest"

echo "Building $IMAGE_NAME:$TAG..."
docker build -t $IMAGE_NAME:$TAG -f Dockerfile.custom .

# Also tag the image with localhost prefix for Act
echo "Adding localhost tag for Act..."
docker tag $IMAGE_NAME:$TAG localhost/$IMAGE_NAME:$TAG

echo ""
echo "To use this image with Act, run:"
echo "act -W .github/workflows/ci.yml"
echo ""
echo "Or for a specific job:"
echo "act -j format -W .github/workflows/ci.yml"
