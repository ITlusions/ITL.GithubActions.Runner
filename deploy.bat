@echo off
setlocal enabledelayedexpansion

:: GitHub Actions Runner Deployment Script for Windows
:: This script installs the Actions Runner Controller dependency and then deploys the GitHub Actions Runner

:: Default values
set "NAMESPACE=actions-runner-system"
set "RELEASE_NAME=github-actions-runner"
set "VALUES_FILE="
set "DRY_RUN=false"
set "UPGRADE=false"

:: Parse command line arguments
:parse_args
if "%~1"=="" goto check_prereqs
if "%~1"=="-n" (
    set "NAMESPACE=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="--namespace" (
    set "NAMESPACE=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="-r" (
    set "RELEASE_NAME=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="--release" (
    set "RELEASE_NAME=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="-f" (
    set "VALUES_FILE=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="--values" (
    set "VALUES_FILE=%~2"
    shift
    shift
    goto parse_args
)
if "%~1"=="-u" (
    set "UPGRADE=true"
    shift
    goto parse_args
)
if "%~1"=="--upgrade" (
    set "UPGRADE=true"
    shift
    goto parse_args
)
if "%~1"=="-d" (
    set "DRY_RUN=true"
    shift
    goto parse_args
)
if "%~1"=="--dry-run" (
    set "DRY_RUN=true"
    shift
    goto parse_args
)
if "%~1"=="-h" goto show_help
if "%~1"=="--help" goto show_help

echo [ERROR] Unknown option: %~1
goto show_help

:show_help
echo GitHub Actions Runner Deployment Script for Windows
echo.
echo Usage: %~nx0 [OPTIONS]
echo.
echo Options:
echo     -n, --namespace     Kubernetes namespace (default: actions-runner-system)
echo     -r, --release       Helm release name (default: github-actions-runner)
echo     -f, --values        Values file to use
echo     -u, --upgrade       Upgrade existing installation
echo     -d, --dry-run       Perform a dry run
echo     -h, --help          Show this help message
echo.
echo Examples:
echo     %~nx0                                      # Install with default values
echo     %~nx0 -f values-production.yaml           # Install with production values
echo     %~nx0 -u -f values-production.yaml        # Upgrade with production values
echo     %~nx0 -d -f values-production.yaml        # Dry run with production values
echo.
echo Prerequisites:
echo     - kubectl configured with cluster access
echo     - Helm 3.x installed
echo     - Cluster with Kubernetes 1.19+
goto end

:check_prereqs
echo [INFO] Checking prerequisites...

:: Check if kubectl exists
kubectl version --client >nul 2>&1
if errorlevel 1 (
    echo [ERROR] kubectl is not installed or not in PATH
    exit /b 1
)

:: Check if helm exists
helm version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Helm is not installed or not in PATH
    exit /b 1
)

:: Check if kubectl can connect to cluster
kubectl cluster-info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Cannot connect to Kubernetes cluster. Please check your kubeconfig.
    exit /b 1
)

echo [SUCCESS] Prerequisites check passed

:: Add Actions Runner Controller Helm repository
echo [INFO] Adding Actions Runner Controller Helm repository...
helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
helm repo update

echo [SUCCESS] Helm repository added and updated

:: Install or upgrade Actions Runner Controller
echo [INFO] Installing/upgrading Actions Runner Controller...

set "ARC_INSTALL_CMD=helm upgrade --install --namespace actions-runner-system --create-namespace --wait actions-runner-controller actions-runner-controller/actions-runner-controller"

if "%DRY_RUN%"=="true" (
    set "ARC_INSTALL_CMD=!ARC_INSTALL_CMD! --dry-run"
)

!ARC_INSTALL_CMD!
if errorlevel 1 (
    echo [ERROR] Failed to install Actions Runner Controller
    exit /b 1
)

echo [SUCCESS] Actions Runner Controller installed/upgraded successfully

:: Build Helm command for GitHub Actions Runner
set "HELM_CMD=helm"

if "%UPGRADE%"=="true" (
    set "HELM_CMD=!HELM_CMD! upgrade"
) else (
    set "HELM_CMD=!HELM_CMD! install"
)

set "HELM_CMD=!HELM_CMD! %RELEASE_NAME% ."
set "HELM_CMD=!HELM_CMD! --namespace %NAMESPACE%"
set "HELM_CMD=!HELM_CMD! --create-namespace"

if not "%VALUES_FILE%"=="" (
    if exist "%VALUES_FILE%" (
        set "HELM_CMD=!HELM_CMD! --values %VALUES_FILE%"
        echo [INFO] Using values file: %VALUES_FILE%
    ) else (
        echo [ERROR] Values file not found: %VALUES_FILE%
        exit /b 1
    )
)

if "%DRY_RUN%"=="true" (
    set "HELM_CMD=!HELM_CMD! --dry-run"
    echo [WARNING] Performing dry run - no actual deployment will occur
)

:: Install/upgrade GitHub Actions Runner
if "%UPGRADE%"=="true" (
    echo [INFO] Upgrading GitHub Actions Runner...
) else (
    echo [INFO] Installing GitHub Actions Runner...
)

!HELM_CMD!
if errorlevel 1 (
    echo [ERROR] Failed to install/upgrade GitHub Actions Runner
    exit /b 1
)

if "%DRY_RUN%"=="true" (
    echo [SUCCESS] Dry run completed successfully
) else if "%UPGRADE%"=="true" (
    echo [SUCCESS] GitHub Actions Runner upgraded successfully
) else (
    echo [SUCCESS] GitHub Actions Runner installed successfully
)

if "%DRY_RUN%"=="false" (
    :: Show deployment status
    echo [INFO] Checking deployment status...
    
    echo.
    echo [INFO] RunnerDeployments:
    kubectl get runnerdeployments -n %NAMESPACE%
    
    echo.
    echo [INFO] Runners:
    kubectl get runners -n %NAMESPACE%
    
    echo.
    echo [INFO] Pods:
    kubectl get pods -n %NAMESPACE% -l app.kubernetes.io/name=github-actions-runner
    
    echo.
    echo [SUCCESS] Deployment completed! Check the output above for the status of your runners.
    echo [INFO] To view logs, run: kubectl logs -n %NAMESPACE% -l app.kubernetes.io/name=github-actions-runner
)

:end
endlocal
