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
  foundations = jsondecode(file(var.foundations_json))
  cluster     = lookup(lookup(local.foundations, "clusters"), var.key)
  labels      = merge({}, local.cluster.labels)
  annotations = merge({
    "community.f5.com/provisioner" = "terraform"
  }, local.cluster.annotations)
}

# Add GCP Firewall rules to allow ingress from internet to the advertised IPSec/
# SSL endpoints.
resource "google_compute_firewall" "xcmesh" {
  project     = local.cluster.project_id
  name        = format("%s-allow-f5xc-mesh", local.cluster.name)
  description = "Allows ingress for F5XC IPSec/SSL connections"
  network     = local.cluster.network
  priority    = 750
  direction   = "INGRESS"
  source_ranges = [
    "0.0.0.0/0",
  ]
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
  # allow {
  #   protocol = "TCP"
  #   ports = [
  #     443,
  #   ]
  # }
}

# Approve the registrations for the site
resource "volterra_registration_approval" "site" {
  for_each     = toset(formatlist("vp-manager-%d", range(0, 3)))
  cluster_name = local.cluster.name
  cluster_size = 3
  hostname     = each.value
}

# Decommision the site on delete
resource "volterra_site_state" "site" {
  name  = local.cluster.name
  state = "DECOMMISSIONING"
  when  = "delete"
  depends_on = [
    volterra_registration_approval.site,
  ]
}

# Update the Site-to-site tunnel IP to public VIP address for private clusters.
resource "volterra_modify_site" "site" {
  name                   = local.cluster.name
  namespace              = "system"
  description            = format("%s GKE site %s", local.cluster.private ? "Private" : "Public", var.key)
  site_to_site_tunnel_ip = local.cluster.vip
  tunnel_type            = "SITE_TO_SITE_TUNNEL_IPSEC"
  depends_on = [
    volterra_registration_approval.site,
    volterra_site_state.site,
  ]
}
