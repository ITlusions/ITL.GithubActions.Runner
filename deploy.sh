#!/bin/bash

# GitHub Actions Runner Deployment Script
# This script installs the Actions Runner Controller dependency and then deploys the GitHub Actions Runner

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
NAMESPACE="actions-runner-system"
RELEASE_NAME="github-actions-runner"
VALUES_FILE=""
DRY_RUN=false
UPGRADE=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show help
show_help() {
    cat << EOF
GitHub Actions Runner Deployment Script

Usage: $0 [OPTIONS]

Options:
    -n, --namespace     Kubernetes namespace (default: actions-runner-system)
    -r, --release       Helm release name (default: github-actions-runner)
    -f, --values        Values file to use
    -u, --upgrade       Upgrade existing installation
    -d, --dry-run       Perform a dry run
    -h, --help          Show this help message

Examples:
    $0                                      # Install with default values
    $0 -f values-production.yaml           # Install with production values
    $0 -u -f values-production.yaml        # Upgrade with production values
    $0 -d -f values-production.yaml        # Dry run with production values

Prerequisites:
    - kubectl configured with cluster access
    - Helm 3.x installed
    - Cluster with Kubernetes 1.19+

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -f|--values)
            VALUES_FILE="$2"
            shift 2
            ;;
        -u|--upgrade)
            UPGRADE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed or not in PATH"
    exit 1
fi

# Check if kubectl can connect to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

print_success "Prerequisites check passed"

# Add Actions Runner Controller Helm repository
print_status "Adding Actions Runner Controller Helm repository..."
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

print_success "Helm repository added and updated"

# Install or upgrade Actions Runner Controller
print_status "Installing/upgrading Actions Runner Controller..."

ARC_INSTALL_CMD="helm upgrade --install --namespace actions-runner-system --create-namespace --wait actions-runner-controller actions-runner-controller/actions-runner-controller"

if [ "$DRY_RUN" = true ]; then
    ARC_INSTALL_CMD="$ARC_INSTALL_CMD --dry-run"
fi

if eval $ARC_INSTALL_CMD; then
    print_success "Actions Runner Controller installed/upgraded successfully"
else
    print_error "Failed to install Actions Runner Controller"
    exit 1
fi

# Build Helm command for GitHub Actions Runner
HELM_CMD="helm"

if [ "$UPGRADE" = true ]; then
    HELM_CMD="$HELM_CMD upgrade"
else
    HELM_CMD="$HELM_CMD install"
fi

HELM_CMD="$HELM_CMD $RELEASE_NAME ."
HELM_CMD="$HELM_CMD --namespace $NAMESPACE"
HELM_CMD="$HELM_CMD --create-namespace"

if [ -n "$VALUES_FILE" ]; then
    if [ -f "$VALUES_FILE" ]; then
        HELM_CMD="$HELM_CMD --values $VALUES_FILE"
        print_status "Using values file: $VALUES_FILE"
    else
        print_error "Values file not found: $VALUES_FILE"
        exit 1
    fi
fi

if [ "$DRY_RUN" = true ]; then
    HELM_CMD="$HELM_CMD --dry-run"
    print_warning "Performing dry run - no actual deployment will occur"
fi

# Install/upgrade GitHub Actions Runner
if [ "$UPGRADE" = true ]; then
    print_status "Upgrading GitHub Actions Runner..."
else
    print_status "Installing GitHub Actions Runner..."
fi

if eval $HELM_CMD; then
    if [ "$DRY_RUN" = true ]; then
        print_success "Dry run completed successfully"
    elif [ "$UPGRADE" = true ]; then
        print_success "GitHub Actions Runner upgraded successfully"
    else
        print_success "GitHub Actions Runner installed successfully"
    fi
else
    print_error "Failed to install/upgrade GitHub Actions Runner"
    exit 1
fi

if [ "$DRY_RUN" = false ]; then
    # Show deployment status
    print_status "Checking deployment status..."
    
    echo
    print_status "RunnerDeployments:"
    kubectl get runnerdeployments -n $NAMESPACE
    
    echo
    print_status "Runners:"
    kubectl get runners -n $NAMESPACE
    
    echo
    print_status "Pods:"
    kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=github-actions-runner
    
    echo
    print_success "Deployment completed! Check the output above for the status of your runners."
    print_status "To view logs, run: kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=github-actions-runner"
fi
