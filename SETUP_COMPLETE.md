# 📊 Prometheus & Grafana Observability Stack - Complete Setup Guide

Welcome! Your EKS cluster now has a production-ready observability stack. This document summarizes everything that was created and how to get started.

## 🎯 What You Got

A complete monitoring and observability solution with:
- **Prometheus**: Metrics collection and storage
- **Grafana**: Beautiful dashboards and alerting
- **Automatic Kubernetes Monitoring**: Nodes, pods, containers pre-configured
- **Persistent Storage**: EBS volumes for data retention
- **RBAC Security**: Proper service accounts and permissions
- **Jenkins Integration**: Ready to monitor your Jenkins CI/CD

## 📁 Files Created/Modified

### 1. **observability.tf** ⭐ MAIN CONFIG
The core Terraform configuration (11KB) containing:
- Kubernetes namespace for monitoring
- Storage classes for EBS volumes
- Prometheus deployment via Helm (kube-prometheus-stack)
- Grafana deployment via Helm
- RBAC roles and service accounts
- Prometheus scrape configuration
- LoadBalancer services for external access
- Pre-configured Prometheus↔Grafana integration

**Status**: ✅ Ready to deploy

### 2. **variables.tf** (Updated)
Added 8 new variables for configuration:
```
prometheus_storage_size         = "50Gi"
prometheus_helm_version         = "57.0.0"
prometheus_service_type         = "LoadBalancer"
grafana_storage_size            = "10Gi"
grafana_helm_version            = "7.0.8"
grafana_admin_password          = "admin123" (CHANGE THIS!)
grafana_service_type            = "LoadBalancer"
```

### 3. **outputs.tf** (Updated)
Added 8 new outputs:
- `monitoring_namespace` - Kubernetes namespace
- `prometheus_endpoint` - URL to access Prometheus
- `prometheus_service_type` - Type of service
- `grafana_endpoint` - URL to access Grafana
- `grafana_service_type` - Type of service
- `grafana_admin_username` - Default: "admin"
- `grafana_admin_password` - Admin password (sensitive)

## 📚 Documentation Files Created

### 1. **OBSERVABILITY_SETUP.md** (Comprehensive Guide)
The main user guide covering:
- Architecture overview with diagrams
- Step-by-step deployment instructions
- How to access Prometheus and Grafana
- Available Kubernetes metrics
- Adding your applications to monitoring
- Setting up alerts and notifications
- Storage retention policies
- Troubleshooting guide

**Start here!** ⭐

### 2. **OBSERVABILITY_ADVANCED.md** (Advanced Customization)
For power users and production setups:
- Custom scrape configurations
- Grafana plugins and dashboards
- AlertManager setup with Slack/PagerDuty
- Ingress configuration (HTTPS/TLS)
- Prometheus scaling and optimization
- Recording rules for performance
- High availability setup
- Cost optimization tips
- PromQL query examples

**Use when**:
- Setting up production monitoring
- Custom scrape targets
- Advanced alerting rules
- Performance tuning

### 3. **JENKINS_INTEGRATION.md** (Jenkins Integration)
How to monitor your Jenkins cluster:
- Enabling Jenkins metrics collection
- Kubernetes service setup
- Prometheus scrape config for Jenkins
- Creating Jenkins dashboards in Grafana
- Jenkins-specific alert rules
- PromQL queries for Jenkins metrics
- Troubleshooting Jenkins metrics

**Use when**:
- You want to monitor Jenkins builds
- Setting up CI/CD pipeline metrics
- Creating Jenkins performance dashboards

### 4. **QUICK_REFERENCE.md** (Cheat Sheet)
Quick commands and operations:
- Pre-deployment checklist
- Quick start (3 steps to running)
- Common kubectl commands
- Configuration changes
- Useful PromQL queries
- Troubleshooting quick fixes
- Grafana quick actions
- Helm operations

**Print this!** 📋

### 5. **IMPLEMENTATION_SUMMARY.md** (This deployment)
Summary of what was created and defaults:
- Overview of components
- Default configurations
- What gets monitored
- Deployment steps
- Access details
- Next steps
- Security considerations
- File locations reference

## 🚀 Quick Start (5 minutes)

```bash
# 1. Deploy
terraform apply

# 2. Wait (2-3 minutes for services to initialize)
kubectl get svc -n monitoring -w

# 3. Get endpoints
terraform output prometheus_endpoint
terraform output grafana_endpoint
terraform output -json | jq .grafana_admin_password -r

# 4. Access Grafana
# Open browser to: http://<grafana-endpoint>:3000
# Username: admin
# Password: (from output above)

# 5. Verify Prometheus
# Open browser to: http://<prometheus-endpoint>:9090
# Click Targets to see what's being monitored
```

## ✅ Deployment Checklist

- [ ] EKS cluster is running
- [ ] EBS CSI driver addon is enabled
- [ ] AWS credentials are configured
- [ ] Ran `terraform init` ✓
- [ ] Ran `terraform plan` ✓
- [ ] Ran `terraform apply`
- [ ] Waited 2-3 minutes
- [ ] Got endpoints with `terraform output`
- [ ] Accessed Grafana and logged in
- [ ] Changed Grafana admin password
- [ ] Viewed Prometheus targets
- [ ] Read OBSERVABILITY_SETUP.md

## 📊 Default Monitoring

Automatically includes metrics for:

**Infrastructure**:
- ✅ Node CPU, memory, disk, network
- ✅ Pod resource usage
- ✅ Container performance
- ✅ Network I/O
- ✅ Disk I/O

**Kubernetes**:
- ✅ API Server metrics
- ✅ Node availability
- ✅ Pod counts and status
- ✅ Service endpoints
- ✅ Replica set health

**Components**:
- ✅ Prometheus itself
- ✅ Node Exporter (on all nodes)
- ✅ kube-state-metrics
- ✅ AlertManager

**Custom Applications** (with annotations):
- ✅ Any app exposing `/metrics`
- ✅ Jenkins
- ✅ Databases
- ✅ Custom services

## 🔒 Important: Security

⚠️ **BEFORE GOING TO PRODUCTION**:

1. **Change Grafana Password**:
   ```bash
   terraform apply -var="grafana_admin_password=YourStrongPassword123!"
   ```

2. **Restrict Access**:
   ```bash
   terraform apply -var="prometheus_service_type=ClusterIP"
   terraform apply -var="grafana_service_type=ClusterIP"
   # Then use Ingress with TLS (see ADVANCED guide)
   ```

3. **Add Authentication**:
   - Enable LDAP in Grafana
   - Add API authentication
   - Set up RBAC policies

4. **Enable Audit Logging**:
   - Monitor who accesses Prometheus
   - Track Grafana dashboard changes

## 📈 Next Steps (Priority Order)

### Immediate (Today):
1. ✅ Deploy with `terraform apply`
2. ✅ Access Grafana and change password
3. ✅ Verify Prometheus targets are UP
4. ✅ Import a community dashboard (ID: 1860)

### Short-term (This week):
1. 📖 Read OBSERVABILITY_SETUP.md
2. 🔔 Set up alerts for common issues
3. 📊 Create custom dashboards
4. 🔌 Add annotations to your pods

### Medium-term (This month):
1. 🔐 Set up Ingress with TLS
2. 📧 Configure AlertManager notifications (Slack/Email)
3. 📈 Create recording rules for performance
4. 📚 Document your alert runbooks

### Long-term (Ongoing):
1. 🎯 Fine-tune alert thresholds
2. 📊 Build domain-specific dashboards
3. 🚀 Optimize storage retention
4. 🔄 Monitor the monitors (meta!)

## 💡 Pro Tips

✨ **Tip 1**: Import dashboards from Grafana Labs (1860, 3686, 6417)
✨ **Tip 2**: Use PromQL to create custom metrics queries
✨ **Tip 3**: Set up alerts before going to production
✨ **Tip 4**: Use `kubectl port-forward` for local testing
✨ **Tip 5**: Monitor Prometheus memory usage - optimize if needed

## 🆘 Common Issues

### LoadBalancer Stuck Pending
- AWS takes 2-3 minutes to create LB
- Use `kubectl get svc -n monitoring -w` to watch
- If >5 min, run `terraform apply` again

### Can't Access Grafana
- Check LoadBalancer has IP: `kubectl get svc -n monitoring`
- Check pod is running: `kubectl get pods -n monitoring`
- Check logs: `kubectl logs -n monitoring -l app.kubernetes.io/name=grafana`

### Grafana Can't Connect to Prometheus
- Verify datasource URL: `http://prometheus-operated:9090`
- Test from Grafana pod: `kubectl exec -it -n monitoring <pod> -- curl http://prometheus-operated:9090`

### High Storage Usage
- Check actual usage: `kubectl exec -it -n monitoring prometheus-0 -- df -h /prometheus`
- Reduce retention: `terraform apply -var="prometheus_storage_size=100Gi"`
- Delete old dashboards in Grafana

**See QUICK_REFERENCE.md for more troubleshooting**

## 📖 Documentation Map

```
Start Here:
├─ This file (SETUP_COMPLETE.md)
│
└─ Choose your path:
   ├─ I want to get started NOW
   │  └─ QUICK_REFERENCE.md (3-page cheat sheet)
   │
   ├─ I want to understand the setup
   │  └─ OBSERVABILITY_SETUP.md (comprehensive guide)
   │
   ├─ I want to monitor Jenkins
   │  └─ JENKINS_INTEGRATION.md (Jenkins + Prometheus)
   │
   └─ I want advanced/production setup
      └─ OBSERVABILITY_ADVANCED.md (power features)
```

## 🔗 Useful Commands

```bash
# Access the services
terraform output prometheus_endpoint
terraform output grafana_endpoint

# Watch services starting up
kubectl get svc -n monitoring -w

# Check all resources
kubectl get all -n monitoring

# View Prometheus config
kubectl get cm -n monitoring prometheus-config -o yaml

# Stream logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f

# Port-forward for local access
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Check storage usage
kubectl describe pvc prometheus-pvc -n monitoring
```

## 📞 Support Resources

| Resource | URL |
|----------|-----|
| Prometheus Docs | https://prometheus.io/docs |
| Grafana Docs | https://grafana.com/docs |
| Kubernetes Metrics | https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-metrics-pipeline/ |
| PromQL Guide | https://prometheus.io/docs/prometheus/latest/querying/ |

## ✨ What's Included

```
✅ Prometheus 2.40+ (kube-prometheus-stack)
✅ Grafana 7.0+
✅ Node Exporter (all nodes)
✅ kube-state-metrics
✅ AlertManager
✅ EBS persistent storage (encrypted)
✅ RBAC configuration
✅ 15 days metric retention
✅ Automatic Kubernetes scraping
✅ LoadBalancer access
✅ Pre-configured datasource
✅ Multiple documentation guides
✅ Jenkins integration ready
```

## 🎓 Learning Resources

1. **Getting Started**: 15 min read of QUICK_REFERENCE.md
2. **Full Setup Guide**: 30 min read of OBSERVABILITY_SETUP.md
3. **Advanced Topics**: OBSERVABILITY_ADVANCED.md as needed
4. **Jenkins Setup**: 20 min read of JENKINS_INTEGRATION.md
5. **Hands-on**: Create your first dashboard (20 min)

**Total time to production**: ~2 hours

## 🗑️ If You Need to Clean Up

```bash
# Remove everything
terraform destroy

# Verify cleaned up
kubectl get ns monitoring
# Should return: not found
```

---

## 🎉 You're Ready!

Your observability stack is ready to deploy. 

**Next step**: Run `terraform apply` and access Grafana within 2-3 minutes!

**Questions?** Check the documentation files listed above, each covers a specific topic.

**Ready to monitor?** Start with QUICK_REFERENCE.md or OBSERVABILITY_SETUP.md

---

**Created**: March 24, 2026
**Terraform Version Required**: >= 1.0
**AWS Provider**: >= 5.0
**Kubernetes Provider**: >= 2.0
**Helm Provider**: >= 2.0

Good luck! 🚀
