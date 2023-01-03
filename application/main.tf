terraform {
  required_version = ">= 1.3"
  required_providers {
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

locals {
  foundations = jsondecode(file(var.foundations_json))
  cluster     = local.foundations.clusters[var.key]
  labels      = merge({}, local.cluster.labels)
  annotations = merge({
    "community.f5.com/provisioner" = "terraform"
  }, local.cluster.annotations)
}

# Create an origin pool for the application
resource "volterra_origin_pool" "app" {
  name                   = format("%s-%s", var.key, var.service_name)
  namespace              = local.foundations.f5xc_app_namespace
  description            = format("%s application origin pool on %s GKE cluster", title(var.key), local.cluster.private ? "Private" : "Public")
  annotations            = local.annotations
  labels                 = local.labels
  endpoint_selection     = "LOCAL_PREFERRED"
  same_as_endpoint_port  = true
  port                   = 8080
  no_tls                 = true
  loadbalancer_algorithm = "LB_OVERRIDE"
  origin_servers {
    k8s_service {
      service_name = format("%s.%s", var.service_name, var.service_namespace)
      site_locator {
        site {
          name      = local.cluster.name
          namespace = "system"
        }
      }
      outside_network = true
    }
    labels = local.labels
  }
}

# Add an HTTP Load balancer
resource "volterra_http_loadbalancer" "app" {
  name        = format("%s-%s", var.key, var.service_name)
  namespace   = local.foundations.f5xc_app_namespace
  description = format("%s HTTP LB to %s GKE cluster", title(var.key), local.cluster.private ? "Private" : "Public")
  annotations = local.annotations
  labels      = local.labels
  advertise_custom {
    advertise_where {
      virtual_site {
        network = "SITE_NETWORK_OUTSIDE"
        virtual_site {
          name      = local.foundations.prefix
          namespace = "shared"
        }
      }
      use_default_port = true
    }
  }
  default_route_pools {
    pool {
      name      = volterra_origin_pool.app.name
      namespace = volterra_origin_pool.app.namespace
    }
    weight   = 1
    priority = 1
  }
  disable_api_definition           = true
  disable_api_discovery            = true
  disable_bot_defense              = true
  disable_client_side_defense      = true
  disable_ddos_detection           = true
  disable_ip_reputation            = true
  disable_malicious_user_detection = true
  disable_rate_limit               = true
  disable_trust_client_ip_headers  = true
  disable_waf                      = true
  domains = [
    format("%s-%s.default", var.key, var.service_name)
  ]
  http {
    dns_volterra_managed = false
    port                 = 80
  }
  no_challenge = true
  round_robin  = true
}
