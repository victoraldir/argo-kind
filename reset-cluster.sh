#!/bin/zsh

# Load .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi

docker stop $KIND_CLUSTER_NAME-control-plane $KIND_CLUSTER_NAME-worker $KIND_CLUSTER_NAME-worker2

docker start $KIND_CLUSTER_NAME-control-plane $KIND_CLUSTER_NAME-worker $KIND_CLUSTER_NAME-worker2

# Check if Kind cluster is running
echo "Checking if Kind cluster is running..."
if kind get clusters | grep -q "$KIND_CLUSTER_NAME"; then
  echo "Kind cluster $KIND_CLUSTER_NAME is running."
else
  echo "Kind cluster $KIND_CLUSTER_NAME is not running."
  exit 1
fi