output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_version" {
  description = "EKS cluster version"
  value       = aws_eks_cluster.main.version
}

output "eks_cluster_certificate_authority" {
  description = "EKS cluster certificate authority data"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "eks_cluster_security_group_id" {
  description = "EKS cluster security group ID"
  value       = aws_security_group.eks_cluster_sg.id
}

output "eks_node_group_id" {
  description = "EKS node group ID"
  value       = aws_eks_node_group.main.id
}

output "eks_node_group_status" {
  description = "EKS node group status"
  value       = aws_eks_node_group.main.status
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = aws_vpc.main.cidr_block
}

# Observability Stack Outputs
output "monitoring_namespace" {
  description = "Monitoring namespace"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "prometheus_endpoint" {
  description = "Prometheus service endpoint"
  value       = kubernetes_service.prometheus_external.status[0].load_balancer[0].ingress[0].hostname != "" ? "http://${kubernetes_service.prometheus_external.status[0].load_balancer[0].ingress[0].hostname}:9090" : "Pending"
}

output "prometheus_service_type" {
  description = "Prometheus service type"
  value       = kubernetes_service.prometheus_external.spec[0].type
}

output "grafana_endpoint" {
  description = "Grafana service endpoint"
  value       = kubernetes_service.grafana_external.status[0].load_balancer[0].ingress[0].hostname != "" ? "http://${kubernetes_service.grafana_external.status[0].load_balancer[0].ingress[0].hostname}:3000" : "Pending"
}

output "grafana_service_type" {
  description = "Grafana service type"
  value       = kubernetes_service.grafana_external.spec[0].type
}

output "grafana_admin_username" {
  description = "Grafana admin username"
  value       = "admin"
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_admin_password
  sensitive   = true
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "jenkins_service_lb_hostname" {
  description = "Jenkins LoadBalancer service hostname"
  value       = try(kubernetes_service_account.jenkins.metadata[0].namespace, "jenkins")
}

output "configure_kubectl_command" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "jenkins_namespace" {
  description = "Jenkins namespace"
  value       = kubernetes_namespace.jenkins.metadata[0].name
}

output "jenkins_helm_release_status" {
  description = "Jenkins Helm release status"
  value       = try(helm_release.jenkins[0].status, "Not deployed")
}

output "storage_class_name" {
  description = "Kubernetes storage class name for Jenkins"
  value       = kubernetes_storage_class.jenkins_ebs.metadata[0].name
}
