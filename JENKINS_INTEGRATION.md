# Jenkins Integration with Prometheus & Grafana

This guide explains how to integrate Jenkins with your new Prometheus and Grafana observability stack.

## Overview

Jenkins can expose metrics in Prometheus format, allowing you to monitor:
- Build duration and success rate
- Job execution metrics
- Plugin performance
- System resource usage
- Queue metrics

## Prerequisites

- Jenkins is running on the EKS cluster
- Prometheus and Grafana are deployed (from observability.tf)
- Jenkins service is accessible from monitoring namespace

## Step 1: Enable Prometheus Metrics in Jenkins

### Option A: Using Jenkins Helm Chart (Recommended)

If deploying Jenkins via Helm, add these values:

```yaml
prometheus:
  enabled: true
  port: 8080
  path: /metrics
```

Or in Terraform (jenkins.tf):

```hcl
set {
  name  = "prometheus.enabled"
  value = "true"
}

set {
  name  = "prometheus.port"
  value = "8080"
}

set {
  name  = "prometheus.path"
  value = "/metrics"
}
```

### Option B: Using Jenkins Prometheus Plugin

1. **Install Plugin**:
   - Jenkins Dashboard → **Manage Jenkins** → **Plugins**
   - Search for **"Prometheus"**
   - Install **"Prometheus metrics"** plugin
   - Restart Jenkins

2. **Configure Plugin**:
   - **Manage Jenkins** → **Configure System**
   - Scroll to **Prometheus**
   - Set:
     - **Endpoints**: `/metrics`
     - **Port**: `8080`
     - **Namespace prefix**: `jenkins_`
   - Click **Save**

3. **Verify**:
   ```bash
   kubectl exec -it -n jenkins <jenkins-pod> -- curl http://localhost:8080/metrics
   ```

## Step 2: Expose Jenkins Metrics Service

Create a Kubernetes service to expose Jenkins metrics:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: jenkins-metrics
  namespace: jenkins
  labels:
    app: jenkins
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 8080
    targetPort: 8080
    protocol: TCP
  selector:
    app.kubernetes.io/name: jenkins
```

Or add to Terraform (jenkins.tf):

```hcl
resource "kubernetes_service" "jenkins_metrics" {
  metadata {
    name      = "jenkins-metrics"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {
    selector = {
      app = "jenkins"
    }

    port {
      name        = "metrics"
      port        = 8080
      target_port = 8080
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [helm_release.jenkins]  # or however Jenkins is deployed
}
```

## Step 3: Configure Prometheus to Scrape Jenkins

Add Jenkins scrape job to Prometheus config. Update the `kubernetes_config_map.prometheus_config` in `observability.tf`:

```hcl
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "prometheus.yml" = base64decode(base64encode(<<-EOT
global:
  scrape_interval: 15s

scrape_configs:
  # ... existing configs ...

  - job_name: 'jenkins'
    honor_timestamps: true
    scrape_interval: 15s
    scrape_timeout: 10s
    metrics_path: '/metrics'
    scheme: http
    static_configs:
      - targets: 
        - jenkins-metrics.jenkins.svc.cluster.local:8080
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        replacement: jenkins
      - source_labels: [__scheme__]
        target_label: scheme
      - source_labels: [__metrics_path__]
        target_label: metrics_path

EOT
    ))
  }
}
```

Or use Kubernetes ServiceMonitor for auto-discovery:

```hcl
resource "kubernetes_manifest" "jenkins_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "jenkins"
      namespace = "jenkins"
      labels = {
        app = "jenkins"
      }
    }
    spec = {
      selector = {
        matchLabels = {
          app = "jenkins"
        }
      }
      endpoints = [
        {
          port   = "metrics"
          path   = "/metrics"
          interval = "15s"
        }
      ]
    }
  }

  depends_on = [kubernetes_service.jenkins_metrics]
}
```

## Step 4: Verify Prometheus is Scraping Jenkins

1. **Check Prometheus Targets**:
   ```bash
   # Port forward to Prometheus
   kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
   ```

2. **Visit**: `http://localhost:9090/targets`

3. **Look for**: Jenkins job and verify status is **UP**

If DOWN, check:
- Jenkins pod is running: `kubectl get pods -n jenkins`
- Jenkins metrics endpoint responds: `kubectl exec -it -n jenkins <jenkins-pod> -- curl http://localhost:8080/metrics | head`
- Network connectivity: `kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus`

## Step 5: Create Jenkins Dashboards in Grafana

### Approach A: Import Community Dashboard

Some community Grafana dashboards include Jenkins:

1. **In Grafana**: Click **+** → **Import**
2. **Search Grafana Labs** for Jenkins dashboards or use IDs:
   - **9524** - Jenkins Instance
   - **6417** - Kubernetes + Jenkins
3. **Select Prometheus** datasource
4. **Click Import**

### Approach B: Create Custom Dashboard

**Example Dashboard: Jenkins Build Metrics**

```json
{
  "dashboard": {
    "title": "Jenkins Metrics",
    "panels": [
      {
        "title": "Build Success Rate",
        "targets": [
          {
            "expr": "rate(jenkins_runs_total{status='success'}[5m]) / rate(jenkins_runs_total[5m]) * 100"
          }
        ]
      },
      {
        "title": "Average Build Duration",
        "targets": [
          {
            "expr": "rate(jenkins_runs_duration_milliseconds_sum[5m]) / rate(jenkins_runs_duration_milliseconds_count[5m])"
          }
        ]
      },
      {
        "title": "Active Builds",
        "targets": [
          {
            "expr": "jenkins_runs_active"
          }
        ]
      },
      {
        "title": "Queue Size",
        "targets": [
          {
            "expr": "jenkins_queue_size_gauge"
          }
        ]
      }
    ]
  }
}
```

**Step-by-step in Grafana UI**:

1. Click **Create** → **Dashboard**
2. Click **Add a new panel**
3. For each metric:
   - Set **Datasource**: Prometheus
   - Write PromQL query (see below)
   - Configure visualization
   - Click **Apply**
4. Click **Save dashboard**

### Useful Jenkins PromQL Queries

```promql
# All Jenkins metrics
{job="jenkins"}

# Build success rate
rate(jenkins_runs_total{status="success"}[5m]) / rate(jenkins_runs_total[5m])

# Failed builds in last 5m
rate(jenkins_runs_total{status="failed"}[5m])

# Average build duration (ms to seconds)
rate(jenkins_runs_duration_milliseconds_sum[5m]) / rate(jenkins_runs_duration_milliseconds_count[5m]) / 1000

# Build queue depth
jenkins_queue_size_gauge

# Active executors
jenkins_executors_in_use

# Total executors available
jenkins_executors_available

# Jenkins process CPU time
rate(jenkins_process_cpu_seconds_total[5m]) * 100

# Jenkins memory usage
jenkins_process_resident_memory_bytes / 1024 / 1024 / 1024

# Plugins loaded
jenkins_plugins_active

# Failed jobs
increase(jenkins_runs_total{status="failed"}[1h])

# Job execution time (job-specific)
rate(jenkins_job_duration_milliseconds_sum{job_name="YourJobName"}[5m]) / rate(jenkins_job_duration_milliseconds_count{job_name="YourJobName"}[5m])

# Build frequency (builds per minute)
rate(jenkins_runs_total[1m])

# Jenkins uptime
jenkins_system_uptime_milliseconds / 1000 / 60 / 60
```

## Step 6: Create Jenkins Alerts

Create alert rules for Jenkins monitoring. Add to `observability.tf`:

```hcl
resource "kubernetes_config_map" "jenkins_alerts" {
  metadata {
    name      = "jenkins-alerts"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }

  data = {
    "jenkins-alerts.yaml" = <<-EOT
groups:
- name: jenkins.rules
  interval: 30s
  rules:
  - alert: JenkinsBuildFailureRate
    expr: |
      (rate(jenkins_runs_total{status="failed"}[5m]) / rate(jenkins_runs_total[5m])) > 0.5
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Jenkins build failure rate is high"
      description: "Build failure rate: {{ $value | humanizePercentage }}"

  - alert: JenkinsHighQueueDepth
    expr: |
      jenkins_queue_size_gauge > 100
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Jenkins build queue is backed up"
      description: "Queue size: {{ $value }}"

  - alert: JenkinsLowExecutors
    expr: |
      (jenkins_executors_available - jenkins_executors_in_use) < 2
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Jenkins has low available executors"
      description: "Available executors: {{ $value }}"

  - alert: JenkinsHighMemory
    expr: |
      (jenkins_process_resident_memory_bytes / (1024*1024*1024)) > 4
    for: 10m
    labels:
      severity: warning
    annotations:
      summary: "Jenkins memory usage is high"
      description: "Memory usage: {{ $value }}GB"

  - alert: JenkinsPodDown
    expr: |
      up{job="jenkins"} == 0
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "Jenkins pod is not responding"
      description: "Jenkins has been unreachable for 2 minutes"

EOT
  }

  depends_on = [kubernetes_namespace.monitoring]
}
```

## Step 7: Connect AlertManager to Notifications

Configure AlertManager to send Jenkins alerts to Slack/Email:

```hcl
# In helm_release.prometheus, update alertmanager config:

set {
  name  = "alertmanager.config.global.slack_api_url"
  value = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
}

set {
  name  = "alertmanager.config.route.receiver"
  value = "jenkins-alerts"
}

set {
  name  = "alertmanager.config.receivers[0].name"
  value = "jenkins-alerts"
}

set {
  name  = "alertmanager.config.receivers[0].slack_configs[0].channel"
  value = "#jenkins-alerts"
}

set {
  name  = "alertmanager.config.receivers[0].slack_configs[0].title"
  value = "Jenkins Alert"
}
```

## Troubleshooting Jenkins Monitoring

### Metrics Endpoint Not Responding

```bash
# Check if Jenkins plugin is installed
kubectl exec -it -n jenkins <jenkins-pod> -- curl -I http://localhost:8080/metrics

# Check logs
kubectl logs -n jenkins <jenkins-pod> | grep -i prometheus

# Restart Jenkins if needed
kubectl delete pod -n jenkins <jenkins-pod>
```

### Prometheus Can't Scrape Jenkins

```bash
# Test connectivity from Prometheus pod
kubectl exec -it -n monitoring prometheus-0 -- \
  curl http://jenkins-metrics.jenkins.svc.cluster.local:8080/metrics

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus | grep jenkins
```

### Grafana Datasource Error

- Verify Prometheus datasource is working: **Configuration** → **Data Sources** → **Prometheus** → **Test**
- Ensure Prometheus pod is running and accessible
- Check network policies aren't blocking traffic

### No Jenkins Metrics in Prometheus

1. Verify Jenkins metrics endpoint:
   ```bash
   kubectl port-forward -n jenkins svc/jenkins 8080:8080
   curl http://localhost:8080/metrics
   ```

2. Check Prometheus scrape config for Jenkins job
3. Wait a few minutes for metrics to be collected (15s scrape interval)
4. Query `up{job="jenkins"}` in Prometheus

## Best Practices

✅ **DO**:
- Monitor build success/failure rates
- Track queue depth and executor availability
- Alert on Jenkins pod availability
- Monitor memory and CPU usage
- Track build duration trends over time

❌ **DON'T**:
- Expose Jenkins outside cluster without RBAC
- Use default credentials in monitoring stack
- Forget to back up Grafana dashboards
- Set retention too low (lose historical data)

## Jenkins Metrics Reference

| Metric | Type | Description |
|--------|------|-------------|
| `jenkins_runs_total` | Counter | Total job runs |
| `jenkins_runs_duration_milliseconds_sum` | Gauge | Build duration sum |
| `jenkins_runs_duration_milliseconds_count` | Counter | Build count |
| `jenkins_queue_size_gauge` | Gauge | Queue depth |
| `jenkins_executors_available` | Gauge | Total executors |
| `jenkins_executors_in_use` | Gauge | Executors in use |
| `jenkins_plugins_active` | Gauge | Active plugins count |
| `jenkins_system_uptime_milliseconds` | Gauge | Uptime in ms |
| `jenkins_process_resident_memory_bytes` | Gauge | Memory usage |
| `jenkins_process_cpu_seconds_total` | Counter | CPU time |

## Next Steps

1. ✅ Enable Jenkins metrics
2. ✅ Verify Prometheus scraping
3. ✅ Create custom Grafana dashboard
4. ✅ Set up alerts
5. ✅ Configure notifications
6. ✅ Create runbooks for alerts

---

**Integration Date**: [Date of setup]
**Jenkins Version**: Check in Jenkins UI
**Prometheus Version**: Check in Prometheus `/graph`
