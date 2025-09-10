#!/bin/bash

# Get the last and current commit SHAs
LAST_COMMIT=$(git rev-parse HEAD^) || { echo "Failed to get last commit SHA"; exit 1; }
CURRENT_COMMIT=$(git rev-parse HEAD) || { echo "Failed to get current commit SHA"; exit 1; }

# Check for changes in client/ and server/ directories
CLIENT_CHANGED=$(git diff --name-only "$LAST_COMMIT" "$CURRENT_COMMIT" | grep '^client/' || true)
SERVER_CHANGED=$(git diff --name-only "$LAST_COMMIT" "$CURRENT_COMMIT" | grep '^server/' || true)

# Initialize flags to track if builds are needed
BUILD_CLIENT=false
BUILD_SERVER=false

# Check if there are changes in client/
if [ -n "$CLIENT_CHANGED" ]; then
  echo "Changes detected in client/ directory. Building client Docker image..."
  BUILD_CLIENT=true
else
  echo "No changes in client/ directory. Skipping client build."
fi

# Check if there are changes in server/
if [ -n "$SERVER_CHANGED" ]; then
  echo "Changes detected in server/ directory. Building server Docker image..."
  BUILD_SERVER=true
else
  echo "No changes in server/ directory. Skipping server build."
fi

service docker start

docker login -u username -p password

# Build client Docker image if changes were detected
if [ "$BUILD_CLIENT" = true ]; then
  # Delete previous client images
  echo "Removing previous client Docker images..."
  docker rmi huymusic987/rmit-store-client:"$LAST_COMMIT" 2>/dev/null || echo "No previous client image with tag $LAST_COMMIT found."
  docker rmi huymusic987/rmit-store-client:latest 2>/dev/null || echo "No previous client image with tag latest found."

  cd client || { echo "Failed to change to client/ directory"; exit 1; }
  if ! docker build -t huymusic987/rmit-store-client:"$CURRENT_COMMIT" .; then
    echo "Client Docker build failed!"
    exit 1
  fi
  if ! docker tag huymusic987/rmit-store-client:"$CURRENT_COMMIT" huymusic987/rmit-store-client:latest; then
    echo "Client Docker tag failed!"
    exit 1
  fi
  if ! docker push huymusic987/rmit-store-client:"$CURRENT_COMMIT"; then
  	echo "Failed to push client image to docker hub"
    exit 1
  fi
  echo "Client Docker image built, tagged and pushed successfully."
  cd .. || { echo "Failed to return to root directory"; exit 1; }
else
  echo "Client image not built."
fi

# Build server Docker image if changes were detected
if [ "$BUILD_SERVER" = true ]; then
  # Delete previous server images
  echo "Removing previous server Docker images..."
  docker rmi huymusic987/rmit-store-server:"$LAST_COMMIT" 2>/dev/null || echo "No previous server image with tag $LAST_COMMIT found."
  docker rmi huymusic987/rmit-store-server:latest 2>/dev/null || echo "No previous server image with tag latest found."

  cd server || { echo "Failed to change to server/ directory"; exit 1; }
  if ! docker build -t huymusic987/rmit-store-server:"$CURRENT_COMMIT" .; then
    echo "Server Docker build failed!"
    exit 1
  fi
  if ! docker tag huymusic987/rmit-store-server:"$CURRENT_COMMIT" huymusic987/rmit-store-server:latest; then
    echo "Server Docker tag failed!"
    exit 1
  fi
  if ! docker push huymusic987/rmit-store-server:"$CURRENT_COMMIT"; then
  	echo "Failed to push server image to docker hub"
    exit 1
  fi
  echo "Server Docker image built, tagged and pushed successfully."
  cd .. || { echo "Failed to return to root directory"; exit 1; }
else
  echo "Server image not built."
fi

service docker stop

exit 0
