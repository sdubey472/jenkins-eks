variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "jenkins-eks"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDR blocks"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "eks_cluster_version" {
  description = "EKS cluster version"
  type        = string
  default     = "1.29"
}

variable "eks_node_group_desired_size" {
  description = "Desired size of EKS node group"
  type        = number
  default     = 3
}

variable "eks_node_group_min_size" {
  description = "Minimum size of EKS node group"
  type        = number
  default     = 2
}

variable "eks_node_group_max_size" {
  description = "Maximum size of EKS node group"
  type        = number
  default     = 5
}

variable "eks_node_instance_types" {
  description = "Instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "jenkins_namespace" {
  description = "Kubernetes namespace for Jenkins"
  type        = string
  default     = "jenkins"
}

variable "jenkins_storage_size" {
  description = "Jenkins persistent volume size"
  type        = string
  default     = "50Gi"
}

variable "enable_jenkins_helm" {
  description = "Enable Jenkins Helm chart deployment"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Project     = "jenkins-eks"
    Environment = "prod"
  }
}

# Prometheus variables
variable "prometheus_storage_size" {
  description = "Prometheus persistent volume size"
  type        = string
  default     = "50Gi"
}

variable "prometheus_helm_version" {
  description = "Prometheus kube-prometheus-stack Helm chart version"
  type        = string
  default     = "57.0.0"
}

variable "prometheus_service_type" {
  description = "Service type for Prometheus (LoadBalancer, NodePort, or ClusterIP)"
  type        = string
  default     = "LoadBalancer"
}

# Grafana variables
variable "grafana_storage_size" {
  description = "Grafana persistent volume size"
  type        = string
  default     = "10Gi"
}

variable "grafana_helm_version" {
  description = "Grafana Helm chart version"
  type        = string
  default     = "7.0.8"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
  default     = "admin123"
}

variable "grafana_service_type" {
  description = "Service type for Grafana (LoadBalancer, NodePort, or ClusterIP)"
  type        = string
  default     = "LoadBalancer"
}
