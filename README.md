# GitHub Actions Runner Helm Chart

This Helm chart deploys GitHub Actions self-hosted runners on Kubernetes using the Actions Runner Controller.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Actions Runner Controller installed in your cluster

## Installation

### 1. Add the Actions Runner Controller repository

```bash
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update
```

### 2. Install Actions Runner Controller

```bash
helm upgrade --install --namespace actions-runner-system --create-namespace \
             --wait actions-runner-controller actions-runner-controller/actions-runner-controller
```

### 3. Install the GitHub Actions Runner

```bash
# Clone this repository or download the chart
git clone <repository-url>
cd ITL.GithubActions.Runner

# Install with default values
helm install my-runners . -n actions-runner-system

# Or install with custom values
helm install my-runners . -n actions-runner-system -f values-custom.yaml
```

## Configuration

### GitHub Authentication

You need to configure GitHub authentication using a GitHub App. See the [Actions Runner Controller documentation](https://github.com/actions-runner-controller/actions-runner-controller/blob/master/docs/authenticating-to-the-github-api.md) for detailed instructions.

#### Required Values

```yaml
github:
  appId: "123456"
  installationId: "12345678"
  privateKey: "LS0tLS1CRUdJTi..." # Base64 encoded private key
  owner: "your-org-or-username"
  repository: "your-repo" # Optional, for repository-scoped runners
```

### Example Configuration

```yaml
# values-custom.yaml
github:
  appId: "123456"
  installationId: "12345678"
  privateKey: "LS0tLS1CRUdJTi..."
  owner: "myorg"
  repository: "myrepo"

runner:
  replicas: 3
  labels:
    - "self-hosted"
    - "linux" 
    - "x64"
    - "gpu"
  resources:
    requests:
      cpu: 1
      memory: 2Gi
    limits:
      cpu: 4
      memory: 8Gi

autoscaling:
  enabled: true
  minReplicas: 1
  maxReplicas: 10
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `github.appId` | string | `""` | GitHub App ID |
| `github.installationId` | string | `""` | GitHub App Installation ID |
| `github.privateKey` | string | `""` | GitHub App private key (base64 encoded) |
| `github.owner` | string | `""` | GitHub organization or user |
| `github.repository` | string | `""` | GitHub repository (optional) |
| `runner.replicas` | int | `2` | Number of runner replicas |
| `runner.image.repository` | string | `"summerwind/actions-runner"` | Runner image repository |
| `runner.image.tag` | string | `"latest"` | Runner image tag |
| `runner.labels` | list | `["self-hosted", "linux", "x64", "itl-runner"]` | Runner labels |
| `runner.ephemeral` | bool | `true` | Enable ephemeral runners |
| `autoscaling.enabled` | bool | `false` | Enable horizontal pod autoscaling |
| `autoscaling.minReplicas` | int | `1` | Minimum number of replicas |
| `autoscaling.maxReplicas` | int | `10` | Maximum number of replicas |

## Troubleshooting

### Check runner status

```bash
kubectl get runnerdeployments -n actions-runner-system
kubectl get runners -n actions-runner-system
```

### View logs

```bash
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=github-actions-runner
```

### Scale manually

```bash
kubectl scale runnerdeployment my-runners-github-actions-runner --replicas=5 -n actions-runner-system
```