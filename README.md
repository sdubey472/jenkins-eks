# Jenkins on EKS - Terraform Project

This Terraform project sets up Jenkins on AWS EKS (Elastic Kubernetes Service) cluster with all necessary infrastructure components.

## Project Structure

```
.
├── main.tf                    # Provider configurations and backend setup
├── variables.tf               # Variable definitions
├── terraform.tfvars          # Terraform variables values
├── vpc.tf                    # VPC, subnets, NAT gateways, route tables
├── eks.tf                    # EKS cluster, node groups, IAM roles, security groups
├── jenkins.tf                # Jenkins Kubernetes deployment
├── outputs.tf                # Output values
└── README.md                 # This file
```

## Prerequisites

1. **AWS Account** - Make sure you have an active AWS account with appropriate permissions
2. **AWS CLI** - Configure AWS CLI with your credentials
3. **Terraform** - Version 1.0 or higher
4. **kubectl** - Kubernetes command-line tool
5. **Helm 3** - Package manager for Kubernetes

### Installation

```bash
# Install Terraform
# macOS
brew install terraform

# Windows
choco install terraform

# Linux
curl https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

## AWS S3 Backend Setup (Required)

Before deploying, create an S3 bucket and DynamoDB table for Terraform state management:

```bash
# Create S3 bucket
aws s3api create-bucket \
  --bucket jenkins-eks-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket jenkins-eks-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## Configuration

### Edit terraform.tfvars

Update the `terraform.tfvars` file with your desired values:

```hcl
aws_region                 = "us-east-1"       # Change to your AWS region
project_name              = "jenkins-eks"      # Change project name
eks_cluster_version       = "1.29"             # EKS version
eks_node_group_desired_size = 3                # Number of worker nodes
eks_node_instance_types   = ["t3.medium"]      # EC2 instance types
jenkins_storage_size      = "50Gi"             # Jenkins persistent volume size
```

## Deployment

### 1. Initialize Terraform

```bash
cd d:\codebase\terraform\jenkins-1
terraform init
```

### 2. Plan the Deployment

```bash
terraform plan -out=tfplan
```

### 3. Apply the Configuration

```bash
terraform apply tfplan
```

The deployment will take approximately 15-20 minutes. Terraform will:
- Create VPC with public and private subnets
- Set up Internet Gateway and NAT Gateways
- Create EKS cluster and worker nodes
- Install EBS CSI driver for persistent volumes
- Deploy Jenkins using Helm charts

### 4. Configure kubectl

After deployment, configure kubectl to access your cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name jenkins-eks-eks
```

### 5. Access Jenkins

Get the Jenkins LoadBalancer endpoint:

```bash
kubectl get -n jenkins services

# Look for the jenkins service and its EXTERNAL-IP
# Then access Jenkins at: http://<EXTERNAL-IP>
```

Default credentials:
- **Username**: admin
- **Password**: ChangeMePassword123!

⚠️ **IMPORTANT**: Change the default password immediately after first login!

## Monitoring and Management

### View EKS Cluster Info

```bash
# Get cluster info
kubectl cluster-info

# View nodes
kubectl get nodes

# View pods in jenkins namespace
kubectl get pods -n jenkins

# View Jenkins pod logs
kubectl logs -n jenkins -l app.kubernetes.io/name=jenkins --tail=100
```

### Access Jenkins Pod

```bash
# Port forward to Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:80

# Then access Jenkins at http://localhost:8080
```

## Security Recommendations

1. **Change default Jenkins password** immediately after deployment
2. **Enable Jenkins authentication** and authorization
3. **Use RBAC** for Kubernetes access control
4. **Enable encryption** for EBS volumes (already configured as gp3)
5. **Set up Network Policies** to restrict traffic
6. **Use Secrets** for sensitive data instead of environment variables
7. **Enable audit logging** for EKS cluster
8. **Regularly patch** Jenkins and plugins

## Scaling

### Scale Worker Nodes

Update `terraform.tfvars`:

```hcl
eks_node_group_desired_size = 5  # Increase from 3 to 5
eks_node_group_max_size     = 10
```

Apply changes:

```bash
terraform apply -target=aws_eks_node_group.main
```

### Increase Jenkins Storage

Update `terraform.tfvars`:

```hcl
jenkins_storage_size = "100Gi"  # Increase from 50Gi
```

This requires manual PVC expansion:

```bash
kubectl patch pvc jenkins-pvc -n jenkins -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

## Cleanup and Destruction

To remove all resources created by Terraform:

```bash
terraform destroy
```

⚠️ **IMPORTANT**: This will delete:
- EKS cluster and all running pods
- VPC and networking components
- Jenkins data (persistent volume)
- All other infrastructure

Manual cleanup may be required for:
- S3 bucket (empty it first, then delete if desired)
- Elastic IP addresses (if not automatically released)
- Security groups (if dependencies exist)

## Troubleshooting

### Cluster creation times out

- Check EC2 instance limits in your AWS account
- Verify IAM permissions
- Check VPC quotas for Elastic IPs

### Jenkins pod stuck in pending

```bash
kubectl describe pod -n jenkins <pod-name>
kubectl get events -n jenkins --sort-by='.lastTimestamp'
```

### Cannot connect to Jenkins LoadBalancer

```bash
# Check service status
kubectl get svc -n jenkins

# Check node security groups
aws ec2 describe-security-groups --filter Name=group-name,Values=*eks-nodes*
```

### Terraform state lock issues

```bash
# View lock status
aws dynamodb scan --table-name terraform-state-lock

# Force unlock (use with caution)
terraform force-unlock <LOCK_ID>
```

## Cost Optimization

1. **Reduce node count** during development
2. **Use Spot instances** for non-critical workloads
3. **Set up auto-scaling** policies
4. **Monitor unused resources** and clean up
5. **Use smaller instance types** if appropriate

## Advanced Configuration

### Adding Jenkins Plugins

Edit `jenkins.tf` and add to `installPlugins` list:

```hcl
installPlugins = [
  "kubernetes:latest",
  "pipeline-aggregator:latest",
  "aws-credentials:latest",
  "your-plugin-name:version",
]
```

### Custom Jenkins Configuration

Create a `jenkins-casc.yaml` file and mount it as a ConfigMap:

```bash
kubectl create configmap jenkins-casc -n jenkins --from-file=jenkins.yaml=jenkins-casc.yaml
```

## Support and Documentation

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Jenkins on Kubernetes](https://www.jenkins.io/doc/book/installing-jenkins/kubernetes/)
- [Helm Charts](https://charts.jenkins.io/)

## License

This Terraform configuration is provided as-is for educational and operational purposes.
