#!/bin/zsh

# Load .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo ".env file not found!"
  exit 1
fi

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check for Docker or Podman
if command_exists docker; then
  echo "Docker is already installed."
elif command_exists podman; then
  echo "Podman is already installed."
else
  echo "Neither Docker nor Podman is installed. Please install one of them to proceed."
  exit 1
fi


# Check for Kind
if command_exists kind; then
  echo "Kind is already installed."
else
  echo "Kind not found. Installing Kind..."
  brew install kind
fi

# Check for Kubectl
if command_exists kubectl; then
  echo "Kubectl is already installed."
else
  echo "Kubectl not found. Installing Kubectl..."
  brew install kubectl
fi

# Check for Git
if command_exists git; then
  echo "Git is already installed."
else
  echo "Git not found. Installing Git..."
  brew install git
fi

# Check Argocd
if command_exists argocd; then
  echo "Argocd is already installed."
else
  echo "Argocd not found. Installing Argocd..."
  brew install argocd
fi
 
 # Check argo workflow cli
if command_exists argo; then
  echo "Argo Workflow CLI is already installed."
else
  echo "Argo Workflow CLI not found. Installing Argo Workflow CLI..."
  brew install argo
fi

 # Check Helm
if command_exists helm; then
  echo "Helm is already installed."
else
  echo "Helm not found. Installing Helm..."
  brew install helm
fi

echo "All required tools are installed."
echo "Starting Kind cluster..."

# Git clone the repository, and ignore if folder already exists
git clone https://github.com/victoraldir/k8s-code.git

cd k8s-code/helper/kind/
kind create cluster --config kind-three-node-cluster.yaml --name "$KIND_CLUSTER_NAME" --wait 5m

# Check if Kind cluster is running
echo "Checking if Kind cluster is running..."
if kind get clusters | grep -q "$KIND_CLUSTER_NAME"; then
  echo "Kind cluster $KIND_CLUSTER_NAME is running."
else
  echo "Kind cluster $KIND_CLUSTER_NAME is not running."
  exit 1
fi

kubectl label node $KIND_CLUSTER_NAME-worker ingress-ready="true"

# Launch ingress controller
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.hostPort.enabled=true \
  --set controller.service.type=NodePort \
  --set controller.hostPort.ports.http=80 \
  --set-string controller.nodeSelector."kubernetes\.io/os"=linux \
  --set-string controller.nodeSelector.ingress-ready="true" \
  --set controller.progressDeadlineSeconds=600

# Install ArgoCD
echo "Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n argocd

echo "Reset admin password to password"
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData": {
    "admin.password": "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU0uh7CaChLa",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'

echo "Exposing ArgoCD server on NodePort 32100"
kubectl patch svc argocd-server -n argocd --patch \
  '{"spec": { "type": "NodePort", "ports": [ { "nodePort": 32100, "port": 443, "protocol": "TCP", "targetPort": 8080 } ] } }'

echo "ArgoCD server is available at https://localhost:32100"
echo "Username: admin"
echo "Password: password"
echo "To access the ArgoCD UI, open your browser and go to https://localhost:32100"

# Installing Argo Rollouts
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Installing Argo CD Image Updater
echo "Installing Argo CD Image Updater..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Wait for image updater to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-image-updater -n argocd

# Create Secret with your GitHub credentials
kubectl -n argocd create secret generic git-creds \
  --from-literal=username=$GITHUB_USERNAME \
  --from-literal=password=$GITHUB_TOKEN

echo "Installing instavote project staging and production environments"
# Create the instavote namespace
kubectl create namespace staging
kubectl create namespace prod

argocd login localhost:32100 --username admin --password password --insecure
argocd repo add https://github.com/victoraldir/argo-labs --insecure-skip-server-verification --project instavote --name instavote-repo

# Installing Argo project
argocd proj create -f ../../../project/instavote-app.yml

# Installing vote app
kubectl apply -f ../../../application/app-vote.yml -n argocd
