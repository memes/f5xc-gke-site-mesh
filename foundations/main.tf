terraform {
  required_version = ">= 1.3"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.42"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.2"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.4"
    }
  }
}

resource "random_pet" "prefix" {
  length = 1
  prefix = var.prefix
  keepers = {
    project_id = var.project_id
    site_token = var.site_token
  }
}

locals {
  # Service accounts have a limit of 30 chars - make sure the generated prefix
  # is not too long such that length("${prefix}-${cluster-key}-bastion") <= 30.
  max_prefix_length = 21 - max([for k, v in var.clusters : length(k)]...)
  prefix            = substr(random_pet.prefix.id, 0, local.max_prefix_length)
  common_labels = merge({
    demo_name   = "f5xc-gke-site-mesh"
    demo_prefix = local.prefix
  }, var.labels)
  resource_names = { for k, v in var.clusters : k => format("%s-%s", local.prefix, k) }
  sa_emails      = { for k, v in var.clusters : k => format("%s@%s.iam.gserviceaccount.com", local.resource_names[k], random_pet.prefix.keepers.project_id) }
  labels = { for k, v in var.clusters : k => merge({
    cluster_key = k
  }, local.common_labels) }
  # GCP resource labels must be lowercase alphanumeric, underscore or hyphen,
  # and the key must be <= 63 characters in length
  gcp_common_labels = { for k, v in local.common_labels : replace(substr(lower(k), 0, 64), "/[^[[:alnum:]]_-]/", "_") => replace(lower(v), "/[^[[:alnum:]]_-]/", "_") }
  gcp_labels = { for k, v in var.clusters : replace(substr(lower(k), 0, 64), "/[^[[:alnum:]]_-]/", "_") => merge({
    cluster_key = replace(lower(k), "/[^[[:alnum:]]_-]/", "_")
  }, local.gcp_common_labels) }
}

data "google_compute_zones" "zones" {
  for_each = toset([for k, v in var.clusters : v.region])
  project  = random_pet.prefix.keepers.project_id
  region   = each.value
  status   = "UP"
}

data "http" "my_address" {
  url = "https://checkip.amazonaws.com"
  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to get local IP address"
    }
  }
}

module "regions" {
  source  = "memes/region-detail/google"
  version = "1.1.0"
  regions = [for k, v in var.clusters : v.region]
}

module "sas" {
  for_each   = var.clusters
  source     = "memes/private-gke-cluster/google//modules/sa/"
  version    = "1.0.2"
  project_id = random_pet.prefix.keepers.project_id
  name       = local.resource_names[each.key]
}

# Create a separate VPC for each cluster
module "vpcs" {
  for_each    = var.clusters
  source      = "memes/multi-region-private-network/google"
  version     = "2.0.0"
  project_id  = random_pet.prefix.keepers.project_id
  name        = local.resource_names[each.key]
  description = format("%s VPC for f5xc-gke-site-mesh demo", title(each.key))
  regions     = [each.value.region]
  cidrs = {
    primary_ipv4_cidr        = "172.16.0.0/12"
    primary_ipv4_subnet_size = 24
    primary_ipv6_cidr        = null
    secondaries = {
      pods = {
        ipv4_cidr        = "10.0.0.0/9"
        ipv4_subnet_size = 16
      }
      services = {
        ipv4_cidr        = "10.128.0.0/16"
        ipv4_subnet_size = 24
      }
    }
  }
  options = {
    nat                   = each.value.private
    delete_default_routes = false
    restricted_apis       = true
    nat_tags              = []
    mtu                   = 1460
    routing_mode          = "GLOBAL"
    flow_logs             = true
    ipv6_ula              = false
    nat_logs              = true
  }
}

# Setup Cloud DNS private zones to return restricted API endpoints for Google APIs
# on all VPCs.
module "restricted_apis_dns" {
  source             = "memes/restricted-apis-dns/google"
  version            = "1.2.0"
  project_id         = random_pet.prefix.keepers.project_id
  name               = format("%s-restricted-apis", local.prefix)
  labels             = local.gcp_common_labels
  network_self_links = [for vpc in module.vpcs : vpc.self_link]
}

# Add a bastion to every VPC with a private cluster
module "bastions" {
  for_each              = { for k, v in var.clusters : k => v if v.private }
  source                = "memes/private-bastion/google"
  version               = "2.3.5"
  project_id            = random_pet.prefix.keepers.project_id
  prefix                = local.resource_names[each.key]
  proxy_container_image = var.bastion_proxy_container_image
  zone                  = data.google_compute_zones.zones[each.value.region].names[0]
  subnet                = module.vpcs[each.key].subnets_by_region[each.value.region].self_link
  labels                = local.gcp_common_labels
  local_port            = try(each.value.bastion_port, 8888)
  bastion_targets = {
    cidrs = [
      "172.16.0.0/12",
    ]
    service_accounts = null
    cidrs            = null
    tags             = null
    priority         = 900
  }
  depends_on = [
    module.vpcs,
    module.restricted_apis_dns,
  ]
}

module "public" {
  for_each                          = { for k, v in var.clusters : k => v if !v.private }
  source                            = "terraform-google-modules/kubernetes-engine/google//modules/beta-public-cluster-update-variant"
  version                           = "24.0.0"
  project_id                        = random_pet.prefix.keepers.project_id
  name                              = local.resource_names[each.key]
  description                       = format("%s public GKE cluster for f5xc-gke-site-mesh demo", title(each.key))
  regional                          = true
  region                            = each.value.region
  release_channel                   = "STABLE"
  create_service_account            = false
  grant_registry_access             = false
  service_account                   = local.sa_emails[each.key]
  cluster_resource_labels           = local.gcp_labels[each.key]
  skip_provisioners                 = true
  issue_client_certificate          = false
  identity_namespace                = "enabled"
  node_metadata                     = "GKE_METADATA"
  disable_legacy_metadata_endpoints = true
  datapath_provider                 = "ADVANCED_DATAPATH"
  ip_range_pods                     = "pods"
  ip_range_services                 = "services"
  network                           = regex("[^/]+$", module.vpcs[each.key].self_link)
  subnetwork                        = regex("[^/]+$", module.vpcs[each.key].subnets_by_region[each.value.region].self_link)
  master_authorized_networks = [
    {
      cidr_block   = format("%s/32", trimspace(data.http.my_address.response_body))
      display_name = format("%s master access", title(each.key))
    },
  ]
  disable_default_snat     = false
  remove_default_node_pool = true
  initial_node_count       = 0
  node_pools = [{
    name         = "alpha"
    auto_repair  = true
    autoscaling  = true
    auto_upgrade = true
    disk_size_gb = 50
    disk_type    = "pd-standard"
    image_type   = "COS_CONTAINERD"
    machine_type = "e2-standard-4"
    min_count    = 1
    max_count    = 3
  }]
  node_pools_labels = {
    alpha = local.gcp_labels[each.key]
  }
  depends_on = [
    module.sas,
    module.vpcs,
  ]
}

module "private" {
  for_each    = { for k, v in var.clusters : k => v if v.private }
  source      = "memes/private-gke-cluster/google"
  version     = "1.0.2"
  project_id  = random_pet.prefix.keepers.project_id
  name        = local.resource_names[each.key]
  description = format("%s private GKE cluster for f5xc-gke-site-mesh demo", title(each.key))
  subnet = {
    self_link           = module.vpcs[each.key].subnets_by_region[each.value.region].self_link
    pods_range_name     = "pods"
    services_range_name = "services"
    master_cidr         = "192.168.0.0/28"
  }
  service_account = local.sa_emails[each.key]
  labels          = local.gcp_labels[each.key]
  node_pools = {
    alpha = {
      auto_upgrade                = true
      autoscaling                 = true
      min_nodes_per_zone          = 1
      max_nodes_per_zone          = 3
      location_policy             = null
      auto_repair                 = true
      disk_size                   = 50
      disk_type                   = "pd-standard"
      image_type                  = "COS_CONTAINERD"
      labels                      = local.gcp_labels[each.key]
      local_ssd_count             = 0
      ephemeral_local_ssd_count   = 0
      machine_type                = "e2-standard-4"
      min_cpu_platform            = null
      preemptible                 = false
      spot                        = false
      boot_disk_kms_key           = null
      enable_gcfs                 = false
      enable_gvnic                = false
      enable_gvisor_sandbox       = false
      enable_secure_boot          = false
      enable_integrity_monitoring = true
      max_surge                   = 1
      max_unavailable             = 0
      placement_policy            = null
      metadata                    = null
      sysctls                     = null
      taints                      = null
      tags                        = null
    }
  }
  master_authorized_networks = [
    {
      cidr_block   = format("%s/32", module.bastions[each.key].ip_address)
      display_name = format("%s bastion access", title(each.key))
    },
  ]
  depends_on = [
    module.sas,
    module.vpcs,
  ]
}

module "kubeconfigs" {
  for_each = merge(
    { for k, v in module.public : k => {
      id                   = v.cluster_id
      use_private_endpoint = false
      proxy_url            = null
      }
    },
    { for k, v in module.private : k => {
      id                   = v.id
      use_private_endpoint = true
      proxy_url            = format("http://:%d", try(var.clusters[k].bastion_port, 8888))
      }
    }
  )
  source               = "memes/private-gke-cluster/google//modules/kubeconfig/"
  version              = "1.0.2"
  cluster_id           = each.value.id
  cluster_name         = each.key
  context_name         = each.key
  use_private_endpoint = each.value.use_private_endpoint
  proxy_url            = each.value.proxy_url
}

# TODO @memes - remove after testing
# Allow SSH to each public node since there isn't a bastion deployed
resource "google_compute_firewall" "ssh" {
  for_each    = { for k, v in var.clusters : k => v if !v.private }
  project     = var.project_id
  name        = format("%s-allow-ssh", local.resource_names[each.key])
  description = "Allows ingress for SSH"
  network     = module.vpcs[each.key].self_link
  priority    = 900
  direction   = "INGRESS"
  source_ranges = [
    format("%s/32", trimspace(data.http.my_address.response_body)),
  ]
  allow {
    protocol = "TCP"
    ports = [
      22,
    ]
  }
}
