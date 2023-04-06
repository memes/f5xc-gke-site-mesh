terraform {
  required_version = ">= 1.3"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.16"
    }
    volterra = {
      source  = "volterraedge/volterra"
      version = ">= 0.11.16"
    }
  }
}

# All configuration for F5XC authentication will be through environment variables
provider "volterra" {
  timeout = "90s"
}

provider "kubernetes" {
  config_path = var.kubeconfig
}

locals {
  foundations = jsondecode(file(var.foundations_json))
  cluster     = local.foundations.clusters[var.key]
  labels      = merge({}, local.cluster.labels)
  annotations = merge({
    "community.f5.com/provisioner" = "terraform"
  }, local.cluster.annotations)
}

data "kubernetes_secret_v1" "secret" {
  metadata {
    name      = var.secret_name
    namespace = var.secret_namespace
  }
  binary_data = {
    "token" = ""
  }
}

module "kubeconfig" {
  source               = "memes/private-gke-cluster/google//modules/kubeconfig/"
  version              = "1.0.1"
  cluster_id           = local.cluster.id
  cluster_name         = var.key
  context_name         = var.key
  use_private_endpoint = true
  user = {
    name  = var.service_account
    token = try(base64decode(data.kubernetes_secret_v1.secret.binary_data["token"]), "")
  }
}

resource "volterra_discovery" "cluster" {
  name        = local.cluster.name
  namespace   = "system"
  description = format("Service discovery for GKE cluster %s", local.cluster.name)
  labels      = local.labels
  annotations = local.annotations
  discovery_k8s {
    access_info {
      kubeconfig_url {
        clear_secret_info {
          url = "string:///${base64encode(module.kubeconfig.kubeconfig)}"
        }
      }
      isolated = true
    }
    publish_info {
      disable = true
    }
  }
  where {
    site {
      ref {
        name      = local.cluster.name
        namespace = "system"
      }
      network_type = "VIRTUAL_NETWORK_SITE_LOCAL_INSIDE"
    }
  }
}
