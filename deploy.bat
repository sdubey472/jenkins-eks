@echo off
REM Jenkins on EKS - Deployment Script for Windows
REM This script deploys the complete Jenkins infrastructure on AWS EKS

setlocal enabledelayedexpansion

REM Color codes (Windows doesn't support ANSI by default, but we'll use text)
set "HEADER=[INFO]"
set "SUCCESS=[SUCCESS]"
set "WARNING=[WARNING]"
set "ERROR=[ERROR]"

cls
echo.
echo ========================================
echo Jenkins on EKS - Deployment Script
echo ========================================
echo.

REM Check prerequisites
echo %HEADER% Checking Prerequisites...
echo.

where terraform >nul 2>nul
if errorlevel 1 (
    echo %ERROR% Terraform is not installed. Please install Terraform 1.0 or higher.
    exit /b 1
)
for /f "tokens=*" %%i in ('terraform version') do set TERRAFORM_VERSION=%%i
echo %SUCCESS% !TERRAFORM_VERSION! is installed
echo.

where aws >nul 2>nul
if errorlevel 1 (
    echo %ERROR% AWS CLI is not installed. Please install AWS CLI.
    exit /b 1
)
for /f "tokens=*" %%i in ('aws --version') do set AWS_VERSION=%%i
echo %SUCCESS% !AWS_VERSION! is installed
echo.

where kubectl >nul 2>nul
if errorlevel 1 (
    echo %WARNING% kubectl is not installed. You'll need it to access the cluster after deployment.
) else (
    echo %SUCCESS% kubectl is installed
)
echo.

where helm >nul 2>nul
if errorlevel 1 (
    echo %WARNING% Helm is not installed. Please install Helm 3 for Jenkins deployment.
) else (
    echo %SUCCESS% Helm is installed
)
echo.

REM Check AWS credentials
aws sts get-caller-identity >nul 2>nul
if errorlevel 1 (
    echo %ERROR% AWS credentials are not configured properly.
    exit /b 1
)
for /f "tokens=*" %%i in ('aws sts get-caller-identity --query Account --output text') do set ACCOUNT_ID=%%i
echo %SUCCESS% AWS account: !ACCOUNT_ID!
echo.

REM Initialize Terraform
echo ========================================
echo %HEADER% Initializing Terraform
echo ========================================
echo.

terraform init
if errorlevel 1 (
    echo %ERROR% Terraform initialization failed.
    exit /b 1
)

echo %SUCCESS% Terraform initialized
echo.

REM Plan Terraform
echo ========================================
echo %HEADER% Planning Terraform Deployment
echo ========================================
echo.

terraform plan -out=tfplan
if errorlevel 1 (
    echo %ERROR% Terraform plan failed.
    exit /b 1
)

echo %SUCCESS% Terraform plan created
echo.

REM Apply Terraform
echo ========================================
echo %HEADER% Applying Terraform Configuration
echo ========================================
echo.

echo This will create the following resources:
echo - VPC with public and private subnets
echo - EKS Cluster
echo - EKS Node Group (Worker Nodes)
echo - Jenkins Helm Release
echo.

set /p RESPONSE="Do you want to proceed? (yes/no): "

if /i "%RESPONSE%"=="yes" (
    terraform apply tfplan
    if errorlevel 1 (
        echo %ERROR% Terraform apply failed.
        exit /b 1
    )
    echo %SUCCESS% Terraform deployment completed
) else (
    echo %WARNING% Deployment cancelled
    exit /b 0
)
echo.

REM Get cluster info
echo ========================================
echo %HEADER% Cluster Information
echo ========================================
echo.

for /f "tokens=*" %%i in ('terraform output -raw eks_cluster_name') do set CLUSTER_NAME=%%i

for /f "tokens=2 delims==" %%i in ('findstr "^aws_region" terraform.tfvars ^| findstr /v "^REM"') do (
    set REGION=%%i
    set REGION=!REGION: =!
    set REGION=!REGION:"=!
)

echo %SUCCESS% Cluster Name: !CLUSTER_NAME!
echo %SUCCESS% Region: !REGION!
echo.

echo ========================================
echo %HEADER% Configuring kubectl
echo ========================================
echo.

aws eks update-kubeconfig --region !REGION! --name !CLUSTER_NAME!
if errorlevel 1 (
    echo %ERROR% Failed to configure kubectl
    exit /b 1
)

echo %SUCCESS% kubectl configured for cluster: !CLUSTER_NAME!
echo.

REM Display post-deployment information
echo ========================================
echo %HEADER% Post-Deployment Configuration
echo ========================================
echo.

echo Useful commands:
echo.
echo 1. View Jenkins service:
echo    kubectl get svc -n jenkins
echo.
echo 2. View Jenkins logs:
echo    kubectl logs -f -n jenkins -l app.kubernetes.io/name=jenkins
echo.
echo 3. Port forward to Jenkins:
echo    kubectl port-forward -n jenkins svc/jenkins 8080:80
echo.
echo 4. View cluster nodes:
echo    kubectl get nodes
echo.
echo 5. Show Terraform outputs:
echo    terraform output
echo.
echo 6. Destroy all resources:
echo    terraform destroy
echo.

REM Wait for Jenkins to be ready (with timeout)
echo ========================================
echo %HEADER% Jenkins Deployment Status
echo ========================================
echo.

echo %WARNING% Waiting for Jenkins deployment (this may take several minutes)...
echo.

echo %SUCCESS% Jenkins Pod Status:
kubectl get pods -n jenkins
echo.

echo %WARNING% To get the LoadBalancer endpoint, run:
echo    kubectl get svc -n jenkins jenkins
echo.

echo %SUCCESS% Default Jenkins Credentials:
echo    Username: admin
echo    Password: ChangeMePassword123!
echo.
echo %WARNING% IMPORTANT: Change the default password immediately after login!
echo.

echo ========================================
echo %SUCCESS% Deployment Complete!
echo ========================================
echo.

pause
