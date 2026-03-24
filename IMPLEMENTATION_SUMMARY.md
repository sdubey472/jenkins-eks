# Prometheus & Grafana Implementation Summary

## What Was Created

I've set up a complete observability stack for your EKS cluster with Prometheus and Grafana. Here's what was added:

### New Files Created

1. **observability.tf** - Main Terraform configuration containing:
   - Monitoring namespace
   - Storage classes for persistent data (EBS volumes)
   - Prometheus deployment via Helm (kube-prometheus-stack)
   - Grafana deployment via Helm
   - Service accounts and RBAC roles for Prometheus
   - Prometheus configuration for scraping Kubernetes metrics
   - LoadBalancer services to expose both Prometheus and Grafana
   - Pre-configured datasource integration

2. **OBSERVABILITY_SETUP.md** - Complete user guide including:
   - Architecture overview
   - Deployment instructions
   - How to access Prometheus and Grafana
   - Configuration variables explanation
   - How to monitor your applications
   - Available metrics reference
   - Setting up alerts
   - Storage and retention policies
   - Troubleshooting guide

3. **OBSERVABILITY_ADVANCED.md** - Advanced customization guide with:
   - Custom scrape configs (example: Jenkins metrics)
   - Grafana plugins and configurations
   - AlertManager setup
   - Ingress configuration alternative
   - Prometheus scaling
   - Custom alert rules
   - Recording rules for performance
   - High availability setup
   - Cost optimization tips
   - PromQL query examples

### Modified Files

1. **variables.tf** - Added 8 new variables:
   - `prometheus_storage_size` (default: 50Gi)
   - `prometheus_helm_version` (default: 57.0.0)
   - `prometheus_service_type` (default: LoadBalancer)
   - `grafana_storage_size` (default: 10Gi)
   - `grafana_helm_version` (default: 7.0.8)
   - `grafana_admin_password` (default: admin123)
   - `grafana_service_type` (default: LoadBalancer)

2. **outputs.tf** - Added 8 new outputs:
   - `monitoring_namespace` - Kubernetes namespace
   - `prometheus_endpoint` - URL to access Prometheus
   - `prometheus_service_type` - Service type
   - `grafana_endpoint` - URL to access Grafana
   - `grafana_service_type` - Service type
   - `grafana_admin_username` - Default admin user
   - `grafana_admin_password` - Admin password (sensitive)

## Default Configuration

### Prometheus
- **Chart**: kube-prometheus-stack v57.0.0
- **Storage**: 50Gi EBS volume
- **Retention**: 15 days or 2GB (whichever comes first)
- **Scraping**: Every 15 seconds
- **Service**: LoadBalancer (can access externally)
- **Includes**: Node Exporter, kube-state-metrics, AlertManager

### Grafana
- **Chart**: grafana v7.0.8
- **Storage**: 10Gi EBS volume
- **Service Type**: LoadBalancer
- **Admin User**: admin
- **Admin Password**: admin123 (CHANGE THIS!)
- **Datasource**: Pre-configured to use Prometheus

## What Gets Monitored by Default

1. **Kubernetes Infrastructure**:
   - API Server metrics
   - Node metrics (CPU, memory, disk, network)
   - Pod metrics
   - Container metrics
   - Service and endpoint metrics

2. **Cluster Health**:
   - Node conditions
   - Pod restart counts
   - Container resource usage
   - Network I/O

3. **Applications** (with proper annotations):
   - Custom metrics from any app that exposes `/metrics`
   - Example: Jenkins, databases, APIs, etc.

## Deployment Steps

1. **Customize variables** (optional):
   ```bash
   cat > monitoring.tfvars << EOF
   prometheus_storage_size = "100Gi"
   grafana_admin_password = "YourSecurePassword123!"
   EOF
   ```

2. **Validate configuration**:
   ```bash
   terraform validate
   ```

3. **Plan deployment**:
   ```bash
   terraform plan -var-file="monitoring.tfvars"
   ```

4. **Deploy**:
   ```bash
   terraform apply -var-file="monitoring.tfvars"
   ```

5. **Get endpoints** (after a few minutes):
   ```bash
   terraform output prometheus_endpoint
   terraform output grafana_endpoint
   terraform output grafana_admin_password
   ```

## Access Details

### Prometheus
- **URL**: http://\<prometheus-endpoint\>:9090
- **No authentication** (add if needed)
- **Targets page**: Shows what's being scraped
- **Query interface**: Write PromQL queries

### Grafana
- **URL**: http://\<grafana-endpoint\>:3000
- **Username**: admin
- **Password**: (from terraform output)
- **Datasource**: Pre-configured Prometheus

## Key Features Included

✅ **Automated Kubernetes Monitoring** - Scrapes KPI from API, nodes, pods
✅ **Long-term Storage** - 15 days of metrics with EBS persistence
✅ **Pre-built Dashboards** - Kubernetes dashboards included
✅ **Easy Alerting** - AlertManager configured for notifications
✅ **RBAC Configured** - Proper service accounts and permissions
✅ **Scalable Storage** - 50Gi + 10Gi EBS volumes (expandable)
✅ **Simple Access** - LoadBalancer services for easy external access
✅ **Cost-optimized** - Reasonable retention and scrape intervals

## Next Steps

1. **Change Grafana Password**:
   ```bash
   terraform apply -var="grafana_admin_password=YourNewPasswordHere"
   ```

2. **Monitor Your Applications**:
   - Add Prometheus annotations to your pod specs
   - Applications expose metrics on `/metrics` endpoint
   - Prometheus auto-discovers and scrapes them

3. **Create Custom Dashboards**:
   - Log into Grafana
   - Create dashboards using PromQL queries
   - Import community dashboards (IDs: 1860, 6417, 9096)

4. **Set up Alerts**:
   - Define alert rules in PrometheusRule resources
   - Configure AlertManager for Slack/PagerDuty/Email
   - Test alert routing

5. **Update Node Count** if needed:
   - Prometheus includes node-exporter on all nodes
   - Scales automatically with your cluster

## Security Considerations

⚠️ **Important for Production**:
- Change Grafana admin password immediately
- Use strong password (currently default: admin123)
- Consider using Ingress with SSL/TLS instead of LoadBalancer
- Add authentication/authorization layer
- Restrict RBAC permissions further if needed
- Enable audit logging for Prometheus queries

## Storage Information

- **Type**: AWS EBS gp3 (General Purpose SSD v3)
- **Prometheus**: 50Gi default (highly compressible time-series data)
- **Grafana**: 10Gi for dashboards, users, settings
- **Encryption**: Enabled by default
- **Auto-expansion**: Enabled
- **Cost**: ~$2/month per 100Gi at current AWS rates

## Troubleshooting

If LoadBalancer is stuck "Pending":
```bash
kubectl get svc -n monitoring -w
# May take a few minutes regardless of setup
```

If Grafana can't connect to Prometheus:
```bash
# Check service DNS
kubectl exec -it -n monitoring <grafana-pod> -- dig prometheus-operated.monitoring.svc.cluster.local
```

Check all components are running:
```bash
kubectl get pods -n monitoring
```

## Cleanup

To remove everything:
```bash
terraform destroy
```

This will delete:
- All Prometheus and Grafana pods
- Persistent volumes and data
- EBS storage
- Kubernetes resources (namespaces, RBAC, storage classes)

## File Locations

```
jenkins-1/
├── observability.tf              ← Main configuration file
├── variables.tf                  ← Updated with new variables
├── outputs.tf                    ← Updated with new outputs
├── OBSERVABILITY_SETUP.md        ← User guide
├── OBSERVABILITY_ADVANCED.md     ← Advanced customization
└── IMPLEMENTATION_SUMMARY.md     ← This file
```

## Useful kubectl Commands

```bash
# View all monitoring resources
kubectl get all -n monitoring

# View Prometheus config map
kubectl get cm -n monitoring prometheus-config -o yaml

# Stream Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f

# Stream Grafana logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f

# Port forward for local access
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
```

## Support & Documentation

- Prometheus: https://prometheus.io/docs
- Grafana: https://grafana.com/docs
- kube-prometheus-stack: https://github.com/prometheus-community/helm-charts
- Kubernetes Metrics: https://kubernetes.io/docs/tasks/debug-application-cluster/resource-metrics-pipeline/

---

**Deployment Date**: $(date)
**Terraform Version**: >= 1.0
**Kubernetes Provider**: >= 2.0
**Helm Provider**: >= 2.0
**AWS Provider**: >= 5.0
