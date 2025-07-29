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

# Install Argo Events
kubectl create namespace argo-events
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml

# Create RBAC Policies
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/master/examples/rbac/sensor-rbac.yaml
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/master/examples/rbac/workflow-rbac.yaml

# Install Event source
kubectl apply -n argo-events -f eventsources/webook-eventsource.yaml

# Create Workflowtemplate
kubectl apply -f workflow-templates/vote-ci-template.yaml

# Add registry credentials to argo-events namespace again with
kubectl create secret -n argo-events docker-registry docker-registry-creds  \
--docker-server=https://index.docker.io/v1/ \
--docker-username=$DOCKER_USERNAME  --docker-password=$DOCKER_PASSWORD

# Create a sensor 
kubectl apply -n argo-events -f sensors/sensor.yaml

# create secret with github token
kubectl create secret generic github-token-secret --from-literal=token=$GITHUB_TOKEN

# Create GitHub Poller cronjob
kubectl apply -f github-pooler/poller-cronjob.yaml

# Install Argo Image Updater
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Create Secret with your GitHub credentials
kubectl -n argocd create secret generic git-creds \
  --from-literal=username=$GITHUB_USERNAME \
  --from-literal=password=$GITHUB_TOKEN

# Path Vote Staging Patch
kubectl patch application --type=merge -n argocd vote-staging --patch-file patch-vote-staging/argo_applications_vote-staging_patch.yaml

# Wait for the Argo server to be ready
echo "Waiting for Argo server to be ready..."
while ! kubectl get pods -n argo | grep -q 'argo-server.*Running'; do
  sleep 5
done

ARGO_TOKEN="Bearer $(kubectl get secret ui-secret -o=jsonpath='{.data.token}' -n argo | base64 --decode)"
echo "Argo UI Token: $ARGO_TOKEN"


kubectl port-forward -n argo svc/argo-server 2746:2746 &
