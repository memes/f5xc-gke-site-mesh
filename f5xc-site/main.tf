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
  # GCP resource labels must be lowercase alphanumeric, underscore or hyphen,
  # and the key must be <= 63 characters in length
  gcp_labels = { for k, v in local.labels : replace(substr(lower(k), 0, 64), "/[^[[:alnum:]]_-]/", "_") => replace(lower(v), "/[^[[:alnum:]]_-]/", "_") }
  annotations = merge({
    "community.f5.com/provisioner" = "terraform"
  }, local.cluster.annotations)
}

data "google_container_cluster" "cluster" {
  project  = local.cluster.project_id
  name     = local.cluster.name
  location = local.cluster.region
}

# Reserve an IP address for the UDP LB
resource "google_compute_address" "ike" {
  count        = local.cluster.private ? 1 : 0
  provider     = google-beta
  project      = local.cluster.project_id
  name         = local.cluster.name
  region       = local.cluster.region
  address_type = "EXTERNAL"
  labels       = local.gcp_labels
}

# Every node in a pool should have a functional kube-proxy healthcheck endpoint;
# use this to see if a node is ready to receive traffic from LB.
resource "google_compute_region_health_check" "ike" {
  count               = local.cluster.private ? 1 : 0
  project             = local.cluster.project_id
  name                = local.cluster.name
  region              = local.cluster.region
  check_interval_sec  = 10
  timeout_sec         = 2
  healthy_threshold   = 2
  unhealthy_threshold = 3
  http_health_check {
    port               = 10256
    port_specification = "USE_FIXED_PORT"
    request_path       = "/healthz"
  }
  log_config {
    enable = false
  }
}

# Create a regional backend service that targets cluster node pools.
resource "google_compute_region_backend_service" "ike" {
  count                 = local.cluster.private ? 1 : 0
  provider              = google-beta
  project               = local.cluster.project_id
  name                  = local.cluster.name
  region                = local.cluster.region
  protocol              = "UDP"
  load_balancing_scheme = "EXTERNAL"
  health_checks         = [for hc in google_compute_region_health_check.ike : hc.id]
  dynamic "backend" {
    for_each = distinct(flatten(concat([for n in data.google_container_cluster.cluster.node_pool : n.managed_instance_group_urls])))
    content {
      group = backend.value
    }
  }
  # TODO @memes - disable after debugging
  log_config {
    enable = true
  }

  # Make sure fragmented UDP packets get sent to the same backend
  # See https://cloud.google.com/load-balancing/docs/network/networklb-backend-service#udp_fragmentation
  session_affinity = "CLIENT_IP_PROTO"
  connection_tracking_policy {
    tracking_mode = "PER_SESSION"
  }
}

# Create a UDP forwarding-rule for the reserved public IP address.
resource "google_compute_forwarding_rule" "ike" {
  count                 = local.cluster.private ? 1 : 0
  project               = local.cluster.project_id
  name                  = local.cluster.name
  region                = local.cluster.region
  ip_address            = google_compute_address.ike[0].address
  ip_protocol           = "UDP"
  load_balancing_scheme = "EXTERNAL"
  labels                = local.gcp_labels
  backend_service       = google_compute_region_backend_service.ike[0].id
  # Make sure fragmented UDP packets get sent to the same backend
  # See https://cloud.google.com/load-balancing/docs/network/networklb-backend-service#udp_fragmentation
  all_ports = true
}

# Make sure NLB health probes can reach the cluster nodes.
resource "google_compute_firewall" "hc" {
  count       = local.cluster.private ? 1 : 0
  project     = local.cluster.project_id
  name        = format("%s-allow-hc", local.cluster.name)
  description = "Allows ingress for GCP healthchecks"
  network     = local.cluster.network
  priority    = 900
  direction   = "INGRESS"
  source_ranges = [
    "35.191.0.0/16",
    "209.85.152.0/22",
    "209.85.204.0/22"
  ]
  allow {
    protocol = "TCP"
    ports = [
      10256,
    ]
  }
}

# Add GCP Firewall rules to allow ingress from internet to the advertised IKE
# nodeports.
resource "google_compute_firewall" "xcmesh" {
  project     = local.cluster.project_id
  name        = format("%s-allow-f5xc-mesh", local.cluster.name)
  description = "Allows ingress for F5XC IPSec connections"
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
  site_to_site_tunnel_ip = try(google_compute_address.ike[0].address, null)
  tunnel_type            = "SITE_TO_SITE_TUNNEL_IPSEC"
  depends_on = [
    volterra_registration_approval.site,
    volterra_site_state.site,
  ]
}
