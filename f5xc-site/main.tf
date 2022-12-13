terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.42"
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

locals {
  cluster = lookup(lookup(jsondecode(file(var.foundations_json)), "clusters"), var.key)
}

resource "google_compute_firewall" "xcmesh" {
  project       = regex("projects/([^/]+)/global", local.cluster.network)[0]
  name          = format("%s-allow-f5xc-mesh", local.cluster.name)
  description   = "Allows ingress for F5XC IPSec connections"
  network       = local.cluster.network
  priority      = 750
  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
  target_service_accounts = [
    local.cluster.sa,
  ]
  allow {
    protocol = "UDP"
    ports = [
      30500,
      30501,
      30502,
    ]
  }
}

# Approve the registrations for the site
resource "volterra_registration_approval" "site" {
  for_each     = toset(formatlist("vp-manager-%d", range(0, 3)))
  cluster_name = local.cluster.name
  cluster_size = 3
  hostname     = each.value
}
