# Advanced Configuration Examples for Observability Stack

This file contains examples for customizing Prometheus and Grafana configurations.

## Custom tfvars Example

Create a `monitoring.tfvars` file with your custom settings:

```hcl
# Prometheus Configuration
prometheus_storage_size           = "100Gi"
prometheus_helm_version           = "57.0.0"
prometheus_service_type           = "LoadBalancer"

# Grafana Configuration
grafana_storage_size              = "20Gi"
grafana_helm_version              = "7.0.8"
grafana_admin_password            = "YourSecurePasswordHere123!"
grafana_service_type              = "LoadBalancer"

# Deploy with custom values
# terraform apply -var-file="monitoring.tfvars"
```

## Enhanced Prometheus Configuration

To use custom scrape configs, update the `kubernetes_config_map.prometheus_config` in `observability.tf`:

### Example: Scraping Jenkins Metrics

```yaml
- job_name: 'jenkins'
  metrics_path: '/metrics'
  static_configs:
    - targets: ['jenkins-service.jenkins.svc.cluster.local:8080']
  relabel_configs:
    - source_labels: [__address__]
      target_label: instance
```

### Example: Custom Application Metrics

```yaml
- job_name: 'custom-app'
  kubernetes_sd_configs:
    - role: pod
  relabel_configs:
    - source_labels: [__meta_kubernetes_pod_label_app]
      action: keep
      regex: 'my-app'
    - source_labels: [__meta_kubernetes_pod_container_port_number]
      action: keep
      regex: '9876'  # Port where your app exposes metrics
```

## Grafana Plugins and Configurations

### Add Grafana Plugins

To add plugins, extend the `helm_release.grafana` resource:

```hcl
set_list {
  name  = "plugins"
  value = [
    "grafana-piechart-panel",
    "grafana-worldmap-panel"
  ]
}
```

### Pre-configured Dashboards

Add provisioning config:

```hcl
set_list {
  name  = "dashboardProviders.dashboardproviders\\.yaml.providers[0].options"
  value = [
    {
      path = "/var/lib/grafana/dashboards"
    }
  ]
}
```

### LDAP Authentication for Grafana

Add to Grafana Helm release:

```hcl
set {
  name  = "ldap.enabled"
  value = "true"
}

set {
  name  = "ldap.config"
  value = base64encode(file("${path.module}/grafana-ldap.toml"))
}
```

## AlertManager Configuration

Configure notification channels. Add to `observability.tf`:

```hcl
# For email notifications
set {
  name  = "alertmanager.config.global.resolve_timeout"
  value = "5m"
}

set {
  name  = "alertmanager.config.route.receiver"
  value = "team-email"
}

set {
  name  = "alertmanager.config.receivers[0].name"
  value = "team-email"
}
```

## Ingress Configuration (Alternative to LoadBalancer)

If using Ingress instead of LoadBalancer:

```hcl
# Replace the prometheus_service_type with ClusterIP
prometheus_service_type = "ClusterIP"

# Add to observability.tf after Grafana helm release:

resource "kubernetes_ingress_v1" "prometheus" {
  metadata {
    name      = "prometheus-ingress"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["prometheus.example.com"]
      secret_name = "prometheus-tls"
    }

    rule {
      host = "prometheus.example.com"
      http {
        path {
          path     = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "prometheus-operated"
              port {
                number = 9090
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_ingress_v1" "grafana" {
  metadata {
    name      = "grafana-ingress"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "nginx"
    tls {
      hosts       = ["grafana.example.com"]
      secret_name = "grafana-tls"
    }

    rule {
      host = "grafana.example.com"
      http {
        path {
          path     = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "grafana"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }
}
```

## Scaling Prometheus

For high-volume metrics, use remote storage:

```hcl
set {
  name  = "prometheus.prometheusSpec.remoteWrite[0].url"
  value = "http://thanos-receive:19291/api/v1/receive"
}
```

## Custom Alert Rules

Create a file `prometheus-rules.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: custom-alerts
  namespace: monitoring
spec:
  groups:
    - name: custom.rules
      interval: 30s
      rules:
        - alert: HighMemoryUsage
          expr: |
            (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 80
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High memory usage detected on {{ $labels.node }}"
            description: "Memory usage is {{ $value }}%"

        - alert: PodCrashLooping
          expr: |
            rate(kube_pod_container_status_restarts_total[15m]) > 0.2
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Pod {{ $labels.pod }} is crash looping"
            description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }}"

        - alert: NodeNotReady
          expr: |
            kube_node_status_condition{condition="Ready",status="true"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node {{ $labels.node }} is not ready"
```

Deploy with kubectl:
```bash
kubectl apply -f prometheus-rules.yaml
```

## Recording Rules for Performance

For frequently used queries, create recording rules:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: recording-rules
  namespace: monitoring
spec:
  groups:
    - name: recording
      interval: 15s
      rules:
        - record: instance:node_cpu:rate5m
          expr: |
            rate(node_cpu_seconds_total[5m])

        - record: instance:node_memory_utilisation:ratio
          expr: |
            (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))

        - record: instance:requests:rate5m
          expr: |
            rate(http_requests_total[5m])
```

## High Availability Setup (Optional)

For production HA, consider:

1. **Multiple Prometheus Replicas** using StatefulSet
2. **Remote Storage Backend** (S3, Thanos, etc.)
3. **Grafana Datasource Redundancy** with load balancing

Add to observability.tf:

```hcl
set {
  name  = "prometheus.prometheusSpec.replicas"
  value = "2"
}

set {
  name  = "prometheus.prometheusSpec.externalLabels.cluster"
  value = aws_eks_cluster.main.name
}
```

## Cost Optimization Tips

1. **Increase scrape interval**:
   ```hcl
   set {
     name  = "prometheus.prometheusSpec.scrapeInterval"
     value = "30s"  # Default is 15s
   }
   ```

2. **Reduce retention**:
   ```hcl
   set {
     name  = "prometheus.prometheusSpec.retention"
     value = "7d"  # Reduce from 15d
   }
   ```

3. **Use spot instances** for the monitoring nodes

4. **Reduce log levels** in production

## Monitoring the Monitors

Monitor Prometheus and Grafana themselves:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: prometheus-self
  namespace: monitoring
spec:
  selector:
    matchLabels:
      prometheus: kube-prometheus
  endpoints:
    - port: web
      interval: 30s
```

## Integration with Slack/PagerDuty

In `observability.tf`, configure alertmanager:

```hcl
set {
  name  = "alertmanager.config.route.receiver"
  value = "slack"
}

set {
  name  = "alertmanager.config.receivers[0].name"
  value = "slack"
}

set {
  name  = "alertmanager.config.receivers[0].slack_configs[0].api_url"
  value = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
}

set {
  name  = "alertmanager.config.receivers[0].slack_configs[0].channel"
  value = "#alerts"
}
```

## Useful PromQL Queries

```promql
# Node CPU Usage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) by (instance) * 100)

# Memory Usage by Pod
sum(container_memory_usage_bytes) by (pod_name)

# Network I/O
rate(container_network_receive_bytes_total[5m])

# Pod Restart Count
kube_pod_container_status_restarts_total

# Container Memory % of Request
container_memory_usage_bytes / kube_pod_container_resource_requests{resource="memory"}
```

## Additional Resources

- [Prometheus Grafana Plugin](https://grafana.com/grafana/plugins/prometheus)
- [Alert Rules Examples](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [PromQL Tutorial](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
