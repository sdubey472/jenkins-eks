#!/bin/bash

# Jenkins on EKS - Deployment Script
# This script deploys the complete Jenkins infrastructure on AWS EKS

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Terraform
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install Terraform 1.0 or higher."
        exit 1
    fi
    print_success "Terraform $(terraform version -json | grep terraform_version | cut -d'"' -f4) is installed"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install AWS CLI."
        exit 1
    fi
    print_success "AWS CLI $(aws --version | cut -d' ' -f1) is installed"
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed. You'll need it to access the cluster after deployment."
    else
        print_success "kubectl $(kubectl version --client --short 2>/dev/null || echo 'is installed')"
    fi
    
    # Check Helm
    if ! command -v helm &> /dev/null; then
        print_warning "Helm is not installed. Please install Helm 3 for Jenkins deployment."
    else
        print_success "Helm $(helm version --short | cut -d':' -f2) is installed"
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured properly."
        exit 1
    fi
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    print_success "AWS account: $ACCOUNT_ID"
}

setup_terraform_backend() {
    print_header "Setting Up Terraform Backend (S3 + DynamoDB)"
    
    BUCKET_NAME="jenkins-eks-terraform-state-$ACCOUNT_ID"
    TABLE_NAME="terraform-state-lock"

    # Robust region parsing (handles spaces/quotes/CRLF)
    REGION=$(awk -F= '/^[[:space:]]*aws_region[[:space:]]*=/{gsub(/["[:space:]\r]/,"",$2); print $2; exit}' terraform.tfvars)
    REGION="${REGION:-us-east-1}"
    
    # Check if bucket exists
    if aws s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
        print_success "S3 bucket '$BUCKET_NAME' already exists"
    else
        print_warning "Creating S3 bucket..."
        if [ "$REGION" = "us-east-1" ]; then
            aws s3api create-bucket --bucket "$BUCKET_NAME" --region "$REGION"
        else
            aws s3api create-bucket \
                --bucket "$BUCKET_NAME" \
                --region "$REGION" \
                --create-bucket-configuration LocationConstraint="$REGION"
        fi
        aws s3api put-bucket-versioning --bucket "$BUCKET_NAME" --versioning-configuration Status=Enabled
        print_success "S3 bucket created and versioning enabled"
    fi    
    # Check if DynamoDB table exists
    if aws dynamodb describe-table --table-name "$TABLE_NAME" --region "$REGION" 2>/dev/null; then
        print_success "DynamoDB table '$TABLE_NAME' already exists"
    else
        print_warning "Creating DynamoDB table..."
        aws dynamodb create-table \
            --table-name "$TABLE_NAME" \
            --attribute-definitions AttributeName=LockID,AttributeType=S \
            --key-schema AttributeName=LockID,KeyType=HASH \
            --billing-mode PAY_PER_REQUEST \
            --region "$REGION"
        print_success "DynamoDB table created"
    fi
    
    # Update terraform backend
    sed -i "s/bucket         = \"jenkins-eks-terraform-state\"/bucket         = \"$BUCKET_NAME\"/" main.tf
    sed -i "s/region         = \"us-east-1\"/region         = \"$REGION\"/" main.tf
}

terraform_init() {
    print_header "Initializing Terraform"
    terraform init
    print_success "Terraform initialized"
}

terraform_plan() {
    print_header "Planning Terraform Deployment"
    terraform plan -out=tfplan
    print_success "Terraform plan created"
}

terraform_apply() {
    print_header "Applying Terraform Configuration"
    echo -e "${YELLOW}This will create the following resources:${NC}"
    echo "- VPC with public and private subnets"
    echo "- EKS Cluster"
    echo "- EKS Node Group (Worker Nodes)"
    echo "- Jenkins Helm Release"
    echo ""

    # Auto-approve if flag is set
    if [[ "${AUTO_APPROVE:-}" == "true" ]]; then
        print_warning "AUTO_APPROVE=true, proceeding..."
        terraform apply tfplan
        print_success "Terraform deployment completed"
        return
    fi

    # Use terraform's built-in prompt instead
    terraform apply tfplan
    print_success "Terraform deployment completed"
}

get_cluster_info() {
    print_header "Cluster Information"
    
    CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
    REGION=$(grep '^aws_region' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')
    
    print_success "Cluster Name: $CLUSTER_NAME"
    print_success "Region: $REGION"
    
    echo ""
    print_header "Configuring kubectl"
    
    aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"
    print_success "kubectl configured for cluster: $CLUSTER_NAME"
    
    # Wait for cluster to be ready
    print_warning "Waiting for cluster nodes to be ready (this may take a few minutes)..."
    kubectl wait --for=condition=Ready node --all --timeout=600s 2>/dev/null || {
        print_warning "Not all nodes are ready yet. This is normal during initial deployment."
        print_warning "You can check node status with: kubectl get nodes"
    }
}

deploy_jenkins() {
    print_header "Jenkins Deployment Status"
    
    JENKINS_NAMESPACE="jenkins"
    
    # Wait for Jenkins to be ready
    print_warning "Waiting for Jenkins pods to be ready..."
    kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=jenkins -n $JENKINS_NAMESPACE --timeout=600s 2>/dev/null || {
        print_warning "Jenkins pods are still deploying. This can take 5-10 minutes."
        print_warning "You can monitor deployment with: kubectl logs -f -n jenkins -l app.kubernetes.io/name=jenkins"
    }
    
    # Get LoadBalancer endpoint
    echo ""
    print_header "Accessing Jenkins"
    
    print_warning "Waiting for LoadBalancer endpoint..."
    for i in {1..30}; do
        LB_ENDPOINT=$(kubectl get svc -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        if [ -n "$LB_ENDPOINT" ]; then
            print_success "Jenkins is accessible at: http://$LB_ENDPOINT"
            break
        fi
        if [ $i -eq 30 ]; then
            print_warning "LoadBalancer endpoint not yet assigned. Trying with IP..."
            LB_IP=$(kubectl get svc -n jenkins jenkins -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
            [ -n "$LB_IP" ] && print_success "Jenkins is accessible at: http://$LB_IP"
        fi
        sleep 2
    done
    
    echo ""
    print_success "Default Credentials:"
    print_success "  Username: admin"
    print_success "  Password: ChangeMePassword123!"
    echo ""
    print_warning "⚠️  IMPORTANT: Change the default password immediately after login!"
}

show_post_deployment_info() {
    print_header "Post-Deployment Configuration"
    
    echo "Here are some useful commands:"
    echo ""
    echo "1. View Jenkins service:"
    echo "   kubectl get svc -n jenkins"
    echo ""
    echo "2. View Jenkins logs:"
    echo "   kubectl logs -f -n jenkins -l app.kubernetes.io/name=jenkins"
    echo ""
    echo "3. Port forward to Jenkins:"
    echo "   kubectl port-forward -n jenkins svc/jenkins 8080:80"
    echo ""
    echo "4. View cluster nodes:"
    echo "   kubectl get nodes"
    echo ""
    echo "5. Show Terraform outputs:"
    echo "   terraform output"
    echo ""
    echo "6. Destroy all resources:"
    echo "   terraform destroy"
    echo ""
}

# Main execution
main() {
    echo ""
    print_header "Jenkins on EKS - Deployment Script"
    echo "Starting deployment at $(date)"
    echo ""
    
    check_prerequisites
    setup_terraform_backend
    terraform_init
    terraform_plan
    terraform_apply
    get_cluster_info
    deploy_jenkins
    show_post_deployment_info
    
    print_header "Deployment Complete!"
    echo "Total time: $(date)"
}

# Run main function
main "$@"
