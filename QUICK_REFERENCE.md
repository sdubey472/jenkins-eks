# Prometheus & Grafana Quick Reference

## 📋 Pre-Deployment Checklist

- [ ] EKS cluster is running
- [ ] EBS CSI driver addon is enabled
- [ ] AWS credentials configured
- [ ] Terraform initialized (`terraform init`)
- [ ] `variables.tf` and `main.tf` verified

## 🚀 Quick Start

```bash
# 1. Deploy observability stack
terraform apply

# 2. Wait for LoadBalancers (2-3 minutes)
kubectl get svc -n monitoring -w

# 3. Get access endpoints
terraform output prometheus_endpoint
terraform output grafana_endpoint
terraform output grafana_admin_password

# 4. Access Grafana at:
# http://<grafana-endpoint>:3000
# Username: admin
# Password: (from output above)
```

## 🔧 Common Commands

### View Status
```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Check services and LoadBalancer IPs
kubectl get svc -n monitoring

# Check persistent volumes
kubectl get pvc -n monitoring

# View Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Then visit http://localhost:9090/targets
```

### Logs & Debugging
```bash
# Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=50 -f

# Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana --tail=50 -f

# Describe a pod
kubectl describe pod -n monitoring <pod-name>

# Get events
kubectl get events -n monitoring --sort-by='.lastTimestamp'
```

### Port Forwarding (if not using LoadBalancer)
```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000 &

# Stop forwarding
jobs
kill %1  # Kill background job 1
```

## ⚙️ Configuration Changes

### Change Grafana Password
```bash
terraform apply -var="grafana_admin_password=NewPassword123"
```

### Increase Storage
```bash
terraform apply \
  -var="prometheus_storage_size=200Gi" \
  -var="grafana_storage_size=50Gi"
```

### Change Service Type (to NodePort)
```bash
terraform apply \
  -var="prometheus_service_type=NodePort" \
  -var="grafana_service_type=NodePort"

# Get NodePort
kubectl get svc -n monitoring
```

### Update Helm Chart Version
```bash
terraform apply -var="prometheus_helm_version=58.0.0"
```

## 📊 Grafana Quick Actions

### Create Dashboard
1. Click **Create** → **Dashboard**
2. Click **Add a new panel**
3. Set Datasource: **Prometheus**
4. Write query (e.g., `up`, `node_memory_MemAvailable_bytes`)
5. Click **Apply** and **Save**

### Import Community Dashboard
1. Click **+** → **Import**
2. Enter Dashboard ID:
   - **1860** - Node Exporter
   - **3686** - Prometheus
   - **6417** - Kubernetes Cluster
   - **9096** - Prometheus Metrics
3. Click **Load** → Select Prometheus datasource → **Import**

### Set Alerts
1. Go to **Alerting** → **Create Alert**
2. Write query condition
3. Configure notifications
4. Save alert

## 📈 Useful PromQL Queries

```promql
# Cluster CPU Usage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node Memory Available
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100

# Pod Memory Usage
sum(container_memory_usage_bytes) by (pod_name)

# Pod CPU Usage (cores)
sum(rate(container_cpu_usage_seconds_total[5m])) by (pod_name)

# Container Restarts
rate(kube_pod_container_status_restarts_total[15m])

# Node Under Pressure
kube_node_status_condition{condition="MemoryPressure"} or kube_node_status_condition{condition="DiskPressure"}

# Pod Errors
rate(kube_pod_container_status_termination_count[5m])

# Network InTrend
rate(container_network_receive_bytes_total[5m])

# Network Out Trend
rate(container_network_transmit_bytes_total[5m])
```

## 🎯 Monitor Your Application

### Step 1: Add Prometheus Annotations
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
      - name: app
        image: my-image:latest
        ports:
        - containerPort: 8080
          name: metrics
```

### Step 2: Expose Metrics in Your App
Your app must respond to `GET /metrics` on port 8080 with Prometheus format metrics.

### Step 3: Verify in Prometheus
1. Visit `http://prometheus:9090/targets`
2. Look for your service under "kubernetes-pods" job
3. Status should show "UP"

## 🔒 Security Quick Tips

```bash
# Change admin password FIRST
terraform apply -var="grafana_admin_password=StrongPassword123!"

# View sensitive outputs
terraform output -json | jq . -r

# Restrict service to ClusterIP (limit external access)
terraform apply -var="prometheus_service_type=ClusterIP"

# Use Ingress with TLS instead of LoadBalancer (see ADVANCED guide)
```

## 🆘 Troubleshooting Quick Fixes

### LoadBalancer Stuck "Pending"
```bash
# Check if service is correctly created
kubectl describe svc prometheus-external -n monitoring

# Manually assign IP in some clusters
# Depends on cloud provider - may need ELB creation
kubectl get svc -n monitoring
```

### Grafana Password Not Working
```bash
# Reset password
kubectl exec -it -n monitoring <grafana-pod> -- grafana-cli admin reset-admin-password newpassword
```

### Can't Access Prometheus from Grafana
```bash
# Check datasource config in Grafana
# URL must be: http://prometheus-operated:9090

# Test from Grafana pod
kubectl exec -it -n monitoring <grafana-pod> -- curl http://prometheus-operated:9090
```

### Pod Metrics Not Appearing
```bash
# Verify pod has scrape annotations
kubectl get pod <pod-name> -o yaml | grep prometheus

# Check Prometheus targets for errors
# Visit http://prometheus:9090/targets

# Verify metrics endpoint works
kubectl port-forward pod/<pod-name> 8080:8080
# In another terminal: curl http://localhost:8080/metrics
```

### High Memory Usage
```bash
# Reduce retention period
terraform apply -var="prometheus_storage_size=30Gi"

# Edit Prometheus config via ConfigMap
kubectl edit cm -n monitoring prometheus-config

# Delete old dashboards in Grafana
# Settings → Admin → Dashboards → Select old ones → Delete
```

## 📦 Helm Operations

### List Installed Releases
```bash
helm list -n monitoring
```

### Upgrade Chart Version
```bash
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  --version 58.0.0
```

### View Helm Values
```bash
helm get values prometheus -n monitoring
helm get values grafana -n monitoring
```

### Rollback to Previous Version
```bash
helm rollback prometheus 1 -n monitoring
helm rollback grafana 1 -n monitoring
```

## 🗑️ Cleanup

### Remove Specific Component
```bash
# Delete Grafana only (keep Prometheus)
terraform destroy -target=helm_release.grafana

# Delete Prometheus (keep Grafana)
terraform destroy -target=helm_release.prometheus
```

### Full Cleanup
```bash
# Remove everything
terraform destroy

# Verify deletion
kubectl get ns monitoring
```

## 📊 Storage Management

### View Storage Usage
```bash
kubectl describe pvc prometheus-pvc -n monitoring
kubectl describe pvc grafana-pvc -n monitoring

# Check actual usage
kubectl exec -it -n monitoring prometheus-0 -- df -h /prometheus
kubectl exec -it -n monitoring grafana-0 -- df -h /var/lib/grafana
```

### Expand Storage
```bash
# Edit PVC and increase storage request
kubectl patch pvc prometheus-pvc -n monitoring \
  -p '{"spec":{"resources":{"requests":{"storage":"200Gi"}}}}'
```

## 🔗 Useful Links

| Resource | URL |
|----------|-----|
| Prometheus Web UI | http://\<prometheus-endpoint\>:9090 |
| Grafana Web UI | http://\<grafana-endpoint\>:3000 |
| Prometheus Docs | https://prometheus.io/docs |
| Grafana Docs | https://grafana.com/docs |
| PromQL Guide | https://prometheus.io/docs/prometheus/latest/querying/ |
| Kubernetes Metrics | https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/ |

## 🎓 Learning Resources

- **Getting Started**: Read `OBSERVABILITY_SETUP.md`
- **Advanced Config**: See `OBSERVABILITY_ADVANCED.md`
- **Full Details**: Refer to `IMPLEMENTATION_SUMMARY.md`
- **Prometheus Book**: https://www.prometheus.io/docs/prometheus/latest/
- **Grafana Tutorials**: https://grafana.com/grafana/tutorials/

---

**Quick Tip**: Save this file for fast reference during troubleshooting!
