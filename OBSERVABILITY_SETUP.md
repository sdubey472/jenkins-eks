# Prometheus and Grafana Observability Setup

This Terraform configuration sets up a complete observability stack using Prometheus and Grafana on your EKS cluster.

## Overview

The setup includes:

- **Prometheus**: Industry-standard metrics collection and storage system
  - Automatically scrapes metrics from Kubernetes components
  - Stores historical data for 15 days
  - Monitors nodes, pods, services, and custom applications
  
- **Grafana**: Visualization and alerting platform
  - Pre-configured to use Prometheus as a datasource
  - Provides dashboards for cluster metrics
  - Enables creating custom visualizations and alerts
  
- **kube-prometheus-stack**: Includes additional components:
  - Node Exporter: Collects node-level metrics
  - kube-state-metrics: Exports Kubernetes object metrics
  - Alertmanager: Handles alert routing and management

## Architecture

```
┌─────────────────────────────────────────────────────┐
│              EKS Cluster                            │
├─────────────────────────────────────────────────────┤
│  Monitoring Namespace                               │
│  ┌────────────────┐        ┌──────────────┐        │
│  │  Prometheus    │┄┄┄┐    │   Grafana    │        │
│  │  - Storage     │   └────→ - Dashboards │        │
│  │  - Scraping    │        │ - Alerting   │        │
│  └────────────────┘        └──────────────┘        │
│         ↑                                            │
│         │ Scrapes metrics from:                     │
│         ├─→ Kubernetes API Server                   │
│         ├─→ Node Exporter                           │
│         ├─→ kube-state-metrics                      │
│         ├─→ All pods (with scrape annotations)      │
│         └─→ Custom applications                     │
└─────────────────────────────────────────────────────┘
```

## Deployment

### Prerequisites

1. EKS cluster is running with EBS CSI driver addon
2. Kubernetes and Helm providers are configured in Terraform
3. AWS credentials are configured

### Deploying

```bash
# Initialize Terraform (if not already done)
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### Configuration Variables

Create or update `terraform.tfvars` with custom values:

```hcl
# Prometheus configuration
prometheus_storage_size    = "100Gi"        # Storage size for Prometheus data
prometheus_helm_version    = "57.0.0"       # Helm chart version
prometheus_service_type    = "LoadBalancer" # Can be: LoadBalancer, NodePort, ClusterIP

# Grafana configuration
grafana_storage_size       = "10Gi"         # Storage size for Grafana data
grafana_helm_version       = "7.0.8"        # Helm chart version
grafana_admin_password     = "SecurePass123" # Change this!
grafana_service_type       = "LoadBalancer" # Can be: LoadBalancer, NodePort, ClusterIP
```

## Accessing the Services

After deployment, get the endpoints:

```bash
terraform output prometheus_endpoint
terraform output grafana_endpoint
```

Or manually:

```bash
# Get LoadBalancer endpoints
kubectl get svc -n monitoring

# Forward ports locally (if not using LoadBalancer)
kubectl port-forward -n monitoring svc/prometheus-external 9090:9090
kubectl port-forward -n monitoring svc/grafana-external 3000:3000
```

### Grafana Access

1. **URL**: `http://<grafana-endpoint>:3000`
2. **Username**: `admin`
3. **Password**: (from `terraform output grafana_admin_password`)

### Prometheus Access

1. **URL**: `http://<prometheus-endpoint>:9090`
2. **Targets**: Check `/targets` to see what's being monitored
3. **Graphs**: Use `/graph` to query metrics directly

## Monitoring Your Applications

### Step 1: Add Prometheus Annotations to Your Pods

For your applications to be scraped by Prometheus, add annotations:

```yaml
apiVersion: v1
kind: Pod
metadata:
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"           # Port where metrics are exposed
    prometheus.io/path: "/metrics"       # Metrics endpoint path
spec:
  containers:
  - name: app
    ports:
    - containerPort: 8080
```

### Step 2: Create Custom Dashboards in Grafana

1. Log into Grafana
2. Click **Create → Dashboard**
3. Add a new panel
4. Set the data source to "Prometheus"
5. Write your queries (e.g., `up`, `container_cpu_usage_seconds_total`)
6. Customize visualization and save

## Key Metrics Available

### Kubernetes Cluster Metrics

- `kube_node_info` - Node information
- `container_cpu_usage_seconds_total` - CPU usage per container
- `container_memory_usage_bytes` - Memory usage per container
- `kube_pod_container_status_restarts_total` - Container restart count
- `up` - Whether target is up
- `kubernetes_build_info` - Kubernetes version info

### Node Metrics (from node-exporter)

- `node_cpu_seconds_total` - CPU time
- `node_memory_MemAvailable_bytes` - Available memory
- `node_disk_io_time_seconds_total` - Disk I/O time
- `node_network_receive_bytes_total` - Network received
- `node_network_transmit_bytes_total` - Network transmitted

## Setting Up Alerts

### Step 1: Create Alert Rules

Add custom alert rules in a ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-alerts
  namespace: monitoring
data:
  alerts.yaml: |
    groups:
    - name: kubernetes.rules
      interval: 30s
      rules:
      - alert: HighPodRestarts
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0.1
        for: 5m
        annotations:
          summary: "Pod {{ $labels.pod }} restarting frequently"
```

### Step 2: Configure Alertmanager

The stack includes Alertmanager for managing alerts. Configure notifications by updating the Helm values for alertmanager in `observability.tf`.

## Storage Details

Both Prometheus and Grafana use EBS volumes (gp3) with:

- **Storage Class**: `prometheus-ebs-sc` and `grafana-ebs-sc`
- **Type**: gp3 (AWS general purpose SSD v3)
- **IOPS**: 3000
- **Throughput**: 125 MB/s
- **Encryption**: Enabled
- **Reclaim Policy**: Delete

Data persists across pod restarts but will be deleted when resources are destroyed.

## Retention Policies

### Prometheus
- **Time-based retention**: 15 days (default)
- **Size-based retention**: 2GB

Adjust in `observability.tf`:
```hcl
set {
  name  = "prometheus.prometheusSpec.retention"
  value = "30d"  # Change retention period
}

set {
  name  = "prometheus.prometheusSpec.retentionSize"
  value = "5GB"  # Change storage limit
}
```

## Upgrade Helm Charts

To upgrade to newer chart versions:

```bash
# Update Helm repositories
helm repo update

# Update specific chart
terraform apply -var="prometheus_helm_version=58.0.0"
```

## Cleanup

To delete the observability stack:

```bash
terraform destroy
```

This will:
- Delete all Prometheus and Grafana resources
- Delete persistent volumes and data
- Release all EBS storage

## Troubleshooting

### Services are Pending LoadBalancer IPs

Check if LoadBalancer is provisioning:
```bash
kubectl describe svc -n monitoring prometheus-external
kubectl describe svc -n monitoring grafana-external
```

If using NodePort, access via:
```
http://<node-ip>:<node-port>
```

Get the node port:
```bash
kubectl get svc -n monitoring
# Look for the EXTERNAL-PORT column
```

### Prometheus Not Scraping Targets

1. Check service monitor:
```bash
kubectl get servicemonitors -n monitoring
```

2. Check Prometheus targets UI:
```
http://<prometheus-endpoint>:9090/targets
```

3. View Prometheus logs:
```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f
```

### Grafana Can't Connect to Prometheus

Verify the datasource URL:
1. In Grafana, go to **Configuration → Data Sources**
2. Click "Prometheus"
3. Ensure URL is `http://prometheus-operated:9090`
4. Click "Test" to verify connectivity

### High Memory/Storage Usage

- Reduce retention period in `observability.tf`
- Lower the `retentionSize`
- Review and optimize scrape configs
- Delete old dashboards in Grafana

## Performance Considerations

- **Prometheus Storage**: Roughly 1.3-2 bytes per sample (TS-compressed)
- **Scrape Interval**: Default 15s; increase to reduce storage needs
- **Number of Metrics**: More targets = more storage needed
- **Query Performance**: Complex queries on large datasets can be slow

## Next Steps

1. **Import Dasboards**: In Grafana, import community dashboards (ID: 1860 for Node Exporter, 3686 for Prometheus)
2. **Setup Alerts**: Configure alerting rules and notification channels
3. **Integrate with Jenkins**: Add Jenkins monitoring annotations to expose Jenkins metrics
4. **Custom Dashboards**: Create dashboards for your specific applications

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Kubernetes Metrics](https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/)
