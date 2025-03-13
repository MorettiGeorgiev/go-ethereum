provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

}

data "aws_eks_cluster_auth" "cluster" {
  name       = local.cluster_name
  depends_on = [module.eks]
}

resource "kubernetes_service_account" "app_sa" {
  metadata {
    name      = "${var.app_name}-sa"
    namespace = var.namespace
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_pod_role.arn
    }
  }
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.app_name
    namespace = var.namespace
    labels = {
      app = var.app_name
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = var.app_name
      }
    }

    template {
      metadata {
        labels = {
          app = var.app_name
        }
      }

      spec {
        service_account_name = kubernetes_service_account.app_sa.metadata[0].name

        container {
          name  = var.app_name
          image = var.image_repo

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
        }
      }
    }
  }
}

resource "kubernetes_service" "app_service" {
  metadata {
    name      = "${var.app_name}-svc"
    namespace = var.namespace
    annotations = {
      "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
    }
  }

  spec {
    selector = {
      app = var.app_name
    }

    type = "LoadBalancer"

    port {
      name        = "http-rpc"
      port        = 8545
      target_port = 8545
      protocol    = "TCP"
    }
    port {
      name        = "ws-rpc"
      port        = 8546
      target_port = 8546
      protocol    = "TCP"

    }
    port {
      name        = "graphql"
      port        = 8547
      target_port = 8547
      protocol    = "TCP"

    }
    port {
      name        = "p2p"
      port        = 30303
      target_port = 30303
      protocol    = "TCP"

    }
  }
}
