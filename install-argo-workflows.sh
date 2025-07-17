#!/bin/zsh

# Load .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi

# Install Argo Workflows
ARGO_WORKFLOWS_VERSION="v3.6.7"

kubectl create namespace argo
kubectl apply -n argo -f "https://github.com/argoproj/argo-workflows/releases/download/$ARGO_WORKFLOWS_VERSION/quick-start-minimal.yaml"


kubectl apply -n argo -f argo-workflows/role-ui-user-read-only.yaml
kubectl apply -n argo -f argo-workflows/secret-ui-user-read-only.yaml

kubectl create sa ui -n argo
kubectl create rolebinding argo-ui-role --role=role-ui-user-read-only --serviceaccount=argo:ui -n argo

# Wait for the Argo server to be ready
echo "Waiting for Argo server to be ready..."
while ! kubectl get pods -n argo | grep -q 'argo-server.*Running'; do
  sleep 5
done

ARGO_TOKEN="Bearer $(kubectl get secret ui-secret -o=jsonpath='{.data.token}' -n argo | base64 --decode)"
echo "Argo UI Token: $ARGO_TOKEN"


kubectl port-forward -n argo svc/argo-server 2746:2746 &