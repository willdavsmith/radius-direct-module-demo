terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.37.1"
    }
  }
}

# A standard, off-the-shelf Terraform module. It has NO `context` input
# variable and NO structured `result` output — nothing Radius-specific.
#
# Radius resolves the `name` / `namespace` parameters from {{context.*}}
# expressions declared in the recipe (see demo/platform.bicep), runs this
# module through the existing Terraform driver, and maps the plain outputs
# in outputs.tf onto the resource's properties via the recipe `outputs` field.
resource "kubernetes_deployment_v1" "redis" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels = {
      app = var.name
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        labels = {
          app = var.name
        }
      }

      spec {
        container {
          name  = "redis"
          image = "ghcr.io/radius-project/mirror/redis:6.2"
          port {
            container_port = var.port
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "redis" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    selector = {
      app = var.name
    }

    port {
      port        = var.port
      target_port = var.port
    }
  }
}
