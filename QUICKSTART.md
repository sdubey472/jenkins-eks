# Quick Start Guide

## 5-Minute Setup

### Step 1: Verify Prerequisites

```bash
# Check all required tools are installed
terraform version
aws --version
kubectl version --client
helm version
```

### Step 2: Configure AWS Credentials

```bash
# Configure AWS CLI with your credentials
aws configure

# Verify credentials are set
aws sts get-caller-identity
```

### Step 3: Create Backend Resources

```bash
# Get your AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket jenkins-eks-terraform-state-${ACCOUNT_ID} \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket jenkins-eks-terraform-state-${ACCOUNT_ID} \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 4: Deploy Infrastructure

#### Option A: Using Deployment Script (Recommended)

**On Linux/macOS:**
```bash
chmod +x deploy.sh
./deploy.sh
```

**On Windows:**
```cmd
deploy.bat
```

#### Option B: Manual Deployment

```bash
# Navigate to the terraform directory
cd d:\codebase\terraform\jenkins-1

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy
terraform apply
```

### Step 5: Access Jenkins

```bash
# Get cluster endpoint
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
REGION=$(grep '^aws_region' terraform.tfvars | cut -d'=' -f2 | tr -d ' "')

# Configure kubectl
aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}

# Get Jenkins LoadBalancer endpoint
kubectl get svc -n jenkins

# Access Jenkins at the EXTERNAL-IP shown above
# Default credentials: admin / ChangeMePassword123!
```

### Step 6: Verify Deployment

```bash
# Check cluster nodes
kubectl get nodes

# Check Jenkins pods
kubectl get pods -n jenkins

# Check Jenkins service
kubectl get svc -n jenkins

# View Jenkins logs
kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins --tail=50
```

## Customization

### Change AWS Region

Edit `terraform.tfvars`:
```hcl
aws_region = "us-west-2"  # or your desired region
```

### Change Cluster Size

Edit `terraform.tfvars`:
```hcl
eks_node_group_desired_size = 5   # Increase nodes
eks_node_instance_types     = ["t3.large"]  # Larger instances
```

### Change Jenkins Storage

Edit `terraform.tfvars`:
```hcl
jenkins_storage_size = "100Gi"  # Increase from 50Gi
```

## Common Commands

```bash
# View all resources
terraform show

# Destroy everything
terraform destroy

# View specific output
terraform output eks_cluster_endpoint

# Refresh Terraform state
terraform refresh

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name jenkins-eks-eks

# Connect to Jenkins pod shell
kubectl exec -it -n jenkins <pod-name> -- /bin/bash

# Port forward to Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:80

# Clean up specific resource
terraform destroy -target=aws_eks_node_group.main

# Remove only Jenkins
helm uninstall jenkins -n jenkins
```

## Troubleshooting

### EKS Cluster taking too long to create
- Check EC2 and VPC quotas in your AWS account
- Verify subnets have available IP addresses

### Jenkins pod stuck in Pending
```bash
# Check what's wrong
kubectl describe pod -n jenkins <pod-name>

# Check PVC status
kubectl get pvc -n jenkins

# Check events
kubectl get events -n jenkins --sort-by='.lastTimestamp'
```

### Cannot access Jenkins LoadBalancer
Wait 5-10 minutes for LoadBalancer to be assigned. Then:
```bash
kubectl get svc -n jenkins jenkins -w
```

### kubeconfig issues
```bash
# Reset kubeconfig
rm ~/.kube/config
aws eks update-kubeconfig --region us-east-1 --name jenkins-eks-eks
```

## Cost Estimation

**Average Monthly Cost** (us-east-1):
- EKS Cluster: ~$73
- 3x t3.medium EC2 nodes: ~$90
- EBS storage (50Gi): ~$5
- NAT Gateway: ~$32
- Data transfer: ~$0-10
- **Total: ~$200/month**

To reduce costs:
- Use t3.small instances
- Reduce node count to 2
- Use Spot instances (save 70%)

## Next Steps

1. **Change Jenkins password**
   - Log in to Jenkins with default credentials
   - Navigate to Admin > Security
   - Change admin password

2. **Configure Jenkins Agents**
   - Go to Manage Jenkins > Configure System
   - Set Kubernetes Cloud configuration

3. **Add Jenkins Plugins**
   - Update plugin list in jenkins.tf
   - Re-apply Terraform: `terraform apply`

4. **Set up CI/CD Pipelines**
   - Create Jenkins jobs
   - Connect to your Git repositories
   - Configure build triggers

5. **Enable HTTPS**
   - Get SSL certificate (ACM or Let's Encrypt)
   - Update Ingress configuration in jenkins.tf

## Support

For issues and detailed documentation, see [README.md](README.md)
