# Prometheus & Grafana - Deployment Checklist & Quick Guide

Print this page for your desk! ✅

---

## 📋 PRE-DEPLOYMENT CHECKLIST

```
Before Running terraform apply:

PREREQUISITES:
☐ EKS cluster is running
☐ EBS CSI driver addon is enabled  
  kubectl get addon -n kube-system | grep ebs-csi
☐ AWS credentials are configured
  aws sts get-caller-identity (should show your account)
☐ kubectl can access cluster
  kubectl get nodes (should list your nodes)
☐ Terraform already initialized
  terraform init (if not done before)

OPTIONAL - CUSTOMIZE FIRST:
☐ Created monitoring.tfvars with custom vars (optional)
☐ Changed grafana_admin_password from default
☐ Decided on service_type (LoadBalancer vs ClusterIP)
☐ Reviewed storage sizes for your needs
```

---

## 🚀 DEPLOYMENT COMMANDS

```bash
# Step 1: Validate Configuration
terraform validate
# Should output: Success! The configuration is valid.

# Step 2: Plan Deployment (Review what will be created)
terraform plan
# Review the ~40 resources that will be created

# Step 3: Deploy (Grab a coffee ☕, takes 3-5 minutes)
terraform apply
# Type: yes
# Wait for completion...

# Step 4: Wait for Services (while resources deploy)
# In another terminal:
kubectl get svc -n monitoring -w
# Watch until prometheus-external and grafana-external 
# show an EXTERNAL-IP (not <pending>)

# Step 5: Get Access Information
terraform output prometheus_endpoint
terraform output grafana_endpoint
terraform output -json | jq .grafana_admin_password -r
# Copy these URLs!
```

---

## ✅ POST-DEPLOYMENT VALIDATION

```bash
# Verify ALL resources are running
kubectl get all -n monitoring
# Should show:
# - prometheus-x pod: Running
# - grafana-x pod: Running  
# - 2 services with EXTERNAL-IP (prometheus-external, grafana-external)

# Check Prometheus is collecting metrics
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
# Open: http://localhost:9090/targets
# All targets should show: UP (green)
# If any DOWN, check logs:
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus --tail=20

# Verify storage is provisioned
kubectl get pvc -n monitoring
# Should show:
# - prometheus-pvc: Bound
# - grafana-pvc: Bound
```

---

## 🔓 INITIAL GRAFANA LOGIN

```
URL: http://<EXTERNAL-IP>:3000
Username: admin
Password: admin123    ← CHANGE THIS IMMEDIATELY!

To change password:
1. Log in with admin/admin123
2. Click profile icon (top right)
3. Click "Change Password"
4. Set new password
5. Click "Change Password" button
```

---

## 📊 VERIFY EVERYTHING WORKS

```
After login to Grafana:

☐ Add Prometheus datasource (should auto-exist):
  - Configuration → Data Sources
  - Click Prometheus
  - Server shows: http://prometheus-operated:9090
  - Click "Test"
  - Should show: "Datasource is working"

☐ Create a simple dashboard:
  - Click "Create" → "Dashboard"
  - Click "Add a new panel"
  - Datasource: Prometheus
  - In query box, type: up
  - Click "Apply"
  - Should see green/red dots for each target
  - Click "Save" and name it "Test Dashboard"

☐ View Prometheus targets:
  - Open: http://<prometheus-ip>:9090/targets
  - Look for "kubernetes-pods" job
  - Should see many targets listed as "UP"
```

---

## 🔑 KEY INFORMATION TO RECORD

Save these for later!

```
Cluster Name: __________________
Prometheus URL: http://__________________:9090
Grafana URL: http://__________________:3000

Grafana Admin User: admin
Grafana Admin Password: __________________

Monitoring Namespace: monitoring
Storage Class Names:
  - Prometheus: prometheus-ebs-sc
  - Grafana: grafana-ebs-sc

Deployed Date: __________________
Deployment By: __________________
```

---

## 🎯 FIRST WEEK TASKS

```
DAY 1 - Setup:
☐ Deploy with terraform apply
☐ Access Grafana
☐ Change Grafana password
☐ Verify Prometheus targets are UP
☐ Create first test dashboard

DAY 2-3 - Exploration:
☐ Import community dashboard (ID: 1860)
☐ Write first PromQL queries
☐ Create custom dashboard for your app
☐ Explore available metrics

DAY 4-5 - Hardening:
☐ Set up basic alert
☐ Configure AlertManager (optional)
☐ Document your dashboards
☐ Plan storage expansion if needed

WEEK 2 - Production:
☐ Add annotations to app pods
☐ Create alert rules for critical systems
☐ Set up Slack/Email notifications
☐ Test failover/recovery scenarios
```

---

## 🆘 QUICK TROUBLESHOOTING

```
ISSUE: LoadBalancer shows <pending> for >5 minutes
FIX: 
  kubectl describe svc prometheus-external -n monitoring
  # Check Events section for errors
  # Usually needs to wait longer or run terraform apply again

ISSUE: Can't access Grafana
FIX:
  kubectl get svc -n monitoring
  # Verify EXTERNAL-IP is set (not <pending>)
  # Try: http://<external-ip>:3000
  kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

ISSUE: Grafana says "Prometheus not reachable"
FIX:
  kubectl exec -it -n monitoring <grafana-pod> -- \
    curl http://prometheus-operated:9090
  # Should return HTML response
  # Check datasource config: Configuration → Data Sources → Prometheus

ISSUE: Only some Prometheus targets are UP
FIX:
  kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus | grep error
  # May be DNS resolution issues or pod not exposing metrics
  # Verify pods have /metrics endpoint

ISSUE: Storage getting full quickly
FIX:
  kubectl exec -it -n monitoring prometheus-0 -- df -h /prometheus
  # Reduce retention:
  terraform apply -var="prometheus_storage_size=100Gi"
  # Or check scrape configs for too many targets
```

---

## 📚 WHICH DOCUMENT TO READ

```
For: "Just get me started!"
→ Read: QUICK_REFERENCE.md (3 pages)

For: "I need to understand how this works"
→ Read: OBSERVABILITY_SETUP.md (complete guide)

For: "How do I monitor my applications?"
→ Read: OBSERVABILITY_SETUP.md (section: Monitoring Your Applications)

For: "I want to monitor Jenkins"
→ Read: JENKINS_INTEGRATION.md

For: "I need advanced/production features"
→ Read: OBSERVABILITY_ADVANCED.md

For: "What was created in my environment?"
→ Read: IMPLEMENTATION_SUMMARY.md

For: "Quick commands I need"
→ Read: QUICK_REFERENCE.md (commands section)
```

---

## 💻 COMMAND REFERENCE (Copy-Paste)

```bash
# Get endpoints
terraform output prometheus_endpoint
terraform output grafana_endpoint

# Watch services deploy
kubectl get svc -n monitoring -w

# Check all resources
kubectl get all -n monitoring

# View configuration
kubectl get cm -n monitoring -o name

# Stream logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f

# Port forward
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
kubectl port-forward -n monitoring svc/grafana 3000:3000 &

# Check storage
kubectl get pvc -n monitoring

# See storage usage
kubectl exec -it -n monitoring prometheus-0 -- df -h /prometheus

# Describe service
kubectl describe svc prometheus-external -n monitoring

# Get events
kubectl get events -n monitoring --sort-by='.lastTimestamp'
```

---

## 🎓 LEARNING PATH (Estimated Times)

```
Time Investment → Knowledge Gained

5 min   → Print and scan this checklist
15 min  → Read QUICK_REFERENCE.md  
30 min  → Read OBSERVABILITY_SETUP.md
30 min  → Create first custom dashboard
1 hour  → Set up alerts
2 hour  → Production hardening (TLS, auth, etc.)
        
Total to comfortable usage: ~2-3 hours
Total to production-ready: ~4-6 hours
```

---

## 🔐 SECURITY REMINDERS

```
BEFORE PRODUCTION:
☐ Change Grafana admin password (not admin123!)
☐ Enable TLS/HTTPS (use Ingress with cert-manager)
☐ Restrict service access (use ClusterIP + Ingress)
☐ Set up authentication (LDAP, OAuth, etc.)
☐ Configure RBAC properly
☐ Enable audit logging
☐ Regular backup of Grafana dashboards

QUICK SECURE SETUP:
1. Change password: terraform apply -var="grafana_admin_password=StrongPass123!"
2. Restrict access: terraform apply -var="grafana_service_type=ClusterIP"
3. Use Ingress with TLS (see OBSERVABILITY_ADVANCED.md)
4. See OBSERVABILITY_ADVANCED.md for full security setup
```

---

## 📞 NEED HELP?

```
Error Type                    → Check File
────────────────────────────────────────────────────
Terraform errors             → Check main.tf, variables.tf syntax
Deployment won't start       → Check EKS cluster status
Services won't get IP        → Check AWS CloudFormation events
Prometheus not scraping      → Check OBSERVABILITY_SETUP.md
Can't login to Grafana       → Check QUICK_REFERENCE.md
Want custom alerts           → Check OBSERVABILITY_ADVANCED.md
Need Jenkins metrics         → Check JENKINS_INTEGRATION.md
General troubleshooting      → Check QUICK_REFERENCE.md
```

---

## 🎉 SUCCESS INDICATORS

You're done when:
```
✅ terraform apply completed successfully
✅ kubectl get svc -n monitoring shows 2 EXTERNAL-IPs
✅ Can access Grafana at http://<ip>:3000
✅ Can access Prometheus at http://<ip>:9090
✅ Logged into Grafana with new password
✅ Prometheus targets show UP status
✅ Can create a test dashboard with metrics

Next: Read OBSERVABILITY_SETUP.md for full capabilities
```

---

## 📅 MAINTENANCE SCHEDULE

```
DAILY:
  - Monitor cluster for alerts

WEEKLY:
  - Check storage usage: kubectl get pvc -n monitoring
  - Review new alerts triggered
  - Check retention policies

MONTHLY:
  - Update Helm charts to latest versions
  - Review and optimize alert rules
  - Backup Grafana dashboards
  - Review logs for errors

QUARTERLY:
  - Capacity planning (storage, compute)
  - Performance optimization
  - Security audit
  - Documentation updates
```

---

**Print this page. Keep at your desk. Reference while deploying! 📋✨**

For detailed information, see the markdown files in your terraform directory.

---

*Last Updated: March 24, 2026*
*Version: 1.0*
