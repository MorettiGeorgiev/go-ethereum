provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    command     = "aws"
  }
}

# Add a dependency on the EKS module to ensure the cluster is fully ready
resource "time_sleep" "wait_for_kubernetes" {
  depends_on = [module.eks]
  create_duration = "30s"
}

resource "kubernetes_deployment" "geth_devnet" {
  depends_on = [time_sleep.wait_for_kubernetes]
  metadata {
    name = "geth-devnet"
    labels = {
      app = "geth-devnet"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "geth-devnet"
      }
    }

    template {
      metadata {
        labels = {
          app = "geth-devnet"
        }
      }

      spec {
        container {
          image = var.docker_image
          name  = "geth-devnet"

          port {
            container_port = 8545
          }
          port {
            container_port = 8546
          }
          port {
            container_port = 8547
          }
          port {
            container_port = 30303
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "2Gi"
            }
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "geth_devnet" {
  depends_on = [kubernetes_deployment.geth_devnet]
  metadata {
    name = "geth-devnet-service"
  }
  spec {
    selector = {
      app = "geth-devnet"
    }
    
    port {
      name        = "http-rpc"
      port        = 8545
      target_port = 8545
    }
    port {
      name        = "ws-rpc"
      port        = 8546
      target_port = 8546
    }
    port {
      name        = "graphql"
      port        = 8547
      target_port = 8547
    }
    port {
      name        = "p2p"
      port        = 30303
      target_port = 30303
    }

    type = "LoadBalancer"
  }
}

output "service_endpoint" {
  value = kubernetes_service.geth_devnet.status[0].load_balancer[0].ingress[0].hostname
  description = "Endpoint to access the Geth devnet"
  depends_on = [kubernetes_service.geth_devnet]
}
