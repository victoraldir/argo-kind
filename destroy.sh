#!/bin/zsh

# Load .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi

# Destroy Kind Cluster. Cluster name is KIND_CLUSTER_NAME
echo "Destroying Kind cluster..."
kind delete cluster --name $KIND_CLUSTER_NAME
