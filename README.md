## Argo Kind
This is just a playground for testing ArgoCD, workflows, rollouts and other Argo projects locally. All you need is a Kubernetes cluster created with kind.

## Requirements
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [argo](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- [argo-workflows](https://argoproj.github.io/argo-workflows/cli/)
- [argo-rollouts](https://argoproj.github.io/argo-rollouts/cli/)
- [argo-events](https://argoproj.github.io/argo-events/cli/)

## Command utils

```bash
# Check the logs for sensor controller 
kubectl logs -n argo-events -l "controller=sensor-controller"

# Check the logs for eventbus controller
kubectl logs -n argo-events -l "controller=eventbus-controller"

# Check the logs for eventsource controller
kubectl logs -n argo-events -l "controller=eventsource-controller"

# List templates
argo template list -A
# OR
kubectl get workflowtemplate -A
