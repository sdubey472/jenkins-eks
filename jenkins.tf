resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.jenkins_namespace
    labels = {
      name = var.jenkins_namespace
    }
  }

  depends_on = [aws_eks_node_group.main]
}

resource "kubernetes_storage_class" "jenkins_ebs" {
  metadata {
    name = "jenkins-ebs-sc"
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



resource "kubernetes_persistent_volume_claim" "jenkins" {
  metadata {
    name      = "jenkins-pvc"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.jenkins_ebs.metadata[0].name

    resources {
      requests = {
        storage = var.jenkins_storage_size
      }
    }
  }

  depends_on = [kubernetes_storage_class.jenkins_ebs]
}

resource "kubernetes_service_account" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  depends_on = [kubernetes_namespace.jenkins]
}

resource "kubernetes_cluster_role" "jenkins" {
  metadata {
    name = "jenkins"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "create", "delete"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get", "create", "delete"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "statefulsets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  depends_on = [kubernetes_namespace.jenkins]
}

resource "kubernetes_cluster_role_binding" "jenkins" {
  metadata {
    name = "jenkins"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.jenkins.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.jenkins.metadata[0].name
    namespace = kubernetes_namespace.jenkins.metadata[0].name
  }

  depends_on = [kubernetes_cluster_role.jenkins]
}

resource "helm_release" "jenkins" {
  count      = var.enable_jenkins_helm ? 1 : 0
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = kubernetes_namespace.jenkins.metadata[0].name
  version    = "5.3.1"

  timeout         = 900  # 15 minutes
  wait            = true
  wait_for_jobs   = true
  atomic          = false
  cleanup_on_fail = false

  values = [
    yamlencode({
      controller = {
        image = {
          tag = "2.504-jdk21"
        }
        admin = {
          username = "admin"
          password = "ChangeMePassword123!"
        }
        serviceType   = "LoadBalancer"
        servicePort   = 80
        targetPort    = 8080
        javaOpts      = "-Xms512m -Xmx512m"
        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "2000m"
            memory = "2Gi"
          }
        }

        # Essential Jenkins plugins
        installPlugins = [
          # Pipeline plugins
          "workflow-aggregator:latest",
          "pipeline-stage-view:latest",
          "pipeline-graph-analysis:latest",
          
          # Kubernetes integration
          "kubernetes:latest",
          "kubernetes-credentials-provider:latest",
          
          # Git plugins
          "git:latest",
          "github:latest",
          "gitlab-plugin:latest",
          "bitbucket:latest",
          
          # Credentials management
          "credentials:latest",
          "credentials-binding:latest",
          "aws-credentials:latest",
          
          # Build tools
          "docker-workflow:latest",
          "docker-plugin:latest",
          "maven-plugin:latest",
          "gradle:latest",
          
          # Configuration as Code
          "configuration-as-code:latest",
          
          # Utilities
          "timestamper:latest",
          "ws-cleanup:latest",
          "build-timeout:latest",
          "ansicolor:latest",
          "rebuild:latest",
          
          # Blue Ocean UI (optional modern UI)
          "blueocean:latest"
        ]
      }

      persistence = {
        enabled      = true
        storageClass = kubernetes_storage_class.jenkins_ebs.metadata[0].name
        size         = var.jenkins_storage_size
        accessMode   = "ReadWriteOnce"
      }

      agent = {
        enabled   = true
        namespace = kubernetes_namespace.jenkins.metadata[0].name
      }

      rbac = {
        create = true
      }

      serviceAccount = {
        create = false
        name   = kubernetes_service_account.jenkins.metadata[0].name
      }
    })
  ]

  depends_on = [
    kubernetes_service_account.jenkins,
    kubernetes_cluster_role_binding.jenkins,
    kubernetes_persistent_volume_claim.jenkins
  ]
}
