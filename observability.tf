# Observability Stack - Prometheus and Grafana
# This file sets up monitoring and alerting infrastructure on EKS

# Create monitoring namespace
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# Storage class for Prometheus persistent data
resource "kubernetes_storage_class" "prometheus_ebs" {
  metadata {
    name = "prometheus-ebs-sc"
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  allow_volume_expansion = true

  parameters = {
    type            = "gp3"
    iops            = "3000"
    throughput      = "125"
    encrypted       = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# Storage class for Grafana persistent data
resource "kubernetes_storage_class" "grafana_ebs" {
  metadata {
    name = "grafana-ebs-sc"
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Delete"
  allow_volume_expansion = true

  parameters = {
    type            = "gp3"
    iops            = "3000"
    throughput      = "125"
    encrypted       = "true"
  }

  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# Service Account for Prometheus
resource "kubernetes_service_account" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# ClusterRole for Prometheus - allows it to scrape metrics from all resources
resource "kubernetes_cluster_role" "prometheus" {
  metadata {
    name = "prometheus"
  }

  rule {
    api_groups = [""]
    resources  = ["nodes", "nodes/proxy", "services", "endpoints", "pods"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# ClusterRoleBinding for Prometheus
resource "kubernetes_cluster_role_binding" "prometheus" {
  metadata {
    name = "prometheus"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.prometheus.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.prometheus.metadata[0].name
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  depends_on = [kubernetes_cluster_role.prometheus]
}

# ConfigMap for Prometheus configuration
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "prometheus.yml" = base64decode(base64encode(<<-EOT
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)

  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: 'true'
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

  - job_name: 'kubernetes-services'
    kubernetes_sd_configs:
      - role: service
    metrics_path: /probe
    params:
      module: [http_2xx]
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_probe]
        action: keep
        regex: 'true'
      - source_labels: [__address__]
        target_label: __param_target
      - target_label: __address__
        replacement: blackbox-exporter:9115
      - source_labels: [__param_target]
        target_label: instance
      - action: labelmap
        regex: __meta_kubernetes_service_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_service_name]
        target_label: kubernetes_name
EOT
    ))
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# PersistentVolumeClaim for Prometheus
resource "kubernetes_persistent_volume_claim" "prometheus" {
  metadata {
    name      = "prometheus-pvc"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.prometheus_ebs.metadata[0].name

    resources {
      requests = {
        storage = var.prometheus_storage_size
      }
    }
  }

  depends_on = [kubernetes_storage_class.prometheus_ebs]
}

# PersistentVolumeClaim for Grafana
resource "kubernetes_persistent_volume_claim" "grafana" {
  metadata {
    name      = "grafana-pvc"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.grafana_ebs.metadata[0].name

    resources {
      requests = {
        storage = var.grafana_storage_size
      }
    }
  }

  depends_on = [kubernetes_storage_class.grafana_ebs]
}

# Prometheus Helm Release
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.prometheus_helm_version

  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "15d"
  }

  set {
    name  = "prometheus.prometheusSpec.retentionSize"
    value = "2GB"
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName"
    value = kubernetes_storage_class.prometheus_ebs.metadata[0].name
  }

  set {
    name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
    value = var.prometheus_storage_size
  }

  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  # Grafana configuration
  set {
    name  = "grafana.enabled"
    value = "false"  # We'll deploy Grafana separately for more control
  }

  # Alertmanager configuration
  set {
    name  = "alertmanager.enabled"
    value = "true"
  }

  set {
    name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.storageClassName"
    value = kubernetes_storage_class.prometheus_ebs.metadata[0].name
  }

  # Node Exporter
  set {
    name  = "nodeExporter.enabled"
    value = "true"
  }

  # Kube State Metrics
  set {
    name  = "kubeStateMetrics.enabled"
    value = "true"
  }

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_cluster_role_binding.prometheus
  ]
}

# Grafana Helm Release
resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "grafana"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = var.grafana_helm_version

  set {
    name  = "persistence.enabled"
    value = "true"
  }

  set {
    name  = "persistence.storageClassName"
    value = kubernetes_storage_class.grafana_ebs.metadata[0].name
  }

  set {
    name  = "persistence.size"
    value = var.grafana_storage_size
  }

  set {
    name  = "adminPassword"
    value = var.grafana_admin_password
  }

  set {
    name  = "service.type"
    value = var.grafana_service_type
  }

  set_list {
    name  = "datasources.datasources\\.yaml.datasources"
    value = [<<-EOT
apiVersion: 1
datasources:
- name: Prometheus
  type: prometheus
  url: http://prometheus-operated:9090
  access: proxy
  isDefault: true
  editable: true
EOT
    ]
  }

  depends_on = [helm_release.prometheus]
}

# Service to expose Prometheus
resource "kubernetes_service" "prometheus_external" {
  metadata {
    name      = "prometheus-external"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    type = var.prometheus_service_type
  }

  depends_on = [helm_release.prometheus]
}

# Service to expose Grafana
resource "kubernetes_service" "grafana_external" {
  metadata {
    name      = "grafana-external"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 3000
      target_port = 3000
      protocol    = "TCP"
    }

    type = var.grafana_service_type
  }

  depends_on = [helm_release.grafana]
}
