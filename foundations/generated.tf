# This file contains generated file resources

locals {
  common_annotations = merge({
    "community.f5.com/demo-name"   = "f5xc-gke-site-mesh"
    "community.f5.com/demo-prefix" = local.prefix
    "community.f5.com/demo-source" = "github.com/memes/f5xc-gke-site-mesh"
  }, var.annotations)
  annotations = { for k, v in var.clusters : k => merge({
    "community.f5.com/cluster-key"  = k
    "community.f5.com/cluster-name" = local.resource_names[k]
    "community.f5.com/cluster-type" = v.private ? "private" : "public"
  }, local.common_annotations) }
}

# Reserve an IP address for the IPSec/SSL tunnels
resource "google_compute_address" "vip" {
  for_each     = { for k, v in var.clusters : k => v if v.private }
  provider     = google-beta
  project      = var.project_id
  name         = local.resource_names[each.key]
  region       = each.value.region
  address_type = "EXTERNAL"
  labels       = local.labels[each.key]
}

resource "local_file" "kubeconfigs" {
  for_each             = module.kubeconfigs
  filename             = format("%s/../generated/%s/kubeconfig.yaml", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content              = each.value.kubeconfig
}

resource "local_file" "application_kustomizations" {
  for_each             = merge(module.public, module.private)
  filename             = format("%s/../generated/%s/application/kustomization.yaml", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content = templatefile("${path.module}/templates/application/kustomization.yaml", {
    annotations = local.annotations[each.key]
    labels      = local.labels[each.key]
  })
}

resource "local_file" "vpm_configs" {
  for_each             = var.clusters
  filename             = format("%s/../generated/%s/f5xc-site/vpm-config.yaml", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content = templatefile("${path.module}/templates/f5xc-site/vpm-config.yaml", {
    name      = local.resource_names[each.key]
    latitude  = module.regions.results[each.value.region].latitude
    longitude = module.regions.results[each.value.region].longitude
    token     = random_pet.prefix.keepers.site_token
    labels    = local.labels[each.key]
  })
}

resource "local_file" "f5xc_kptfile" {
  for_each             = merge(module.public, module.private)
  filename             = format("%s/../generated/%s/f5xc-site/Kptfile", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content = templatefile("${path.module}/templates/f5xc-site/Kptfile", {
    name = each.key
  })
}

resource "local_file" "f5xc_kustomizations" {
  for_each             = merge(module.public, module.private)
  filename             = format("%s/../generated/%s/f5xc-site/kustomization.yaml", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content = templatefile("${path.module}/templates/f5xc-site/kustomization.yaml", {
    annotations = local.annotations[each.key]
    labels      = local.labels[each.key]
    vip         = try(google_compute_address.vip[each.key].address, null)
  })
}

resource "local_file" "service_discovery_kustomizations" {
  for_each             = merge(module.public, module.private)
  filename             = format("%s/../generated/%s/service-discovery/kustomization.yaml", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content = templatefile("${path.module}/templates/service-discovery/kustomization.yaml", {
    name        = local.resource_names[each.key]
    annotations = local.annotations[each.key]
    labels      = local.labels[each.key]
  })
}

resource "local_file" "json" {
  filename             = "${path.module}/../generated/foundations.json"
  file_permission      = "0644"
  directory_permission = "0755"
  content = jsonencode({
    prefix             = local.prefix
    common_annotations = local.common_annotations
    common_labels      = local.common_labels
    f5xc_app_namespace = var.f5xc_app_namespace
    clusters = { for k, v in var.clusters : k => {
      name           = local.resource_names[k]
      id             = try(module.public[k].cluster_id, module.private[k].id)
      project_id     = var.project_id
      region         = var.clusters[k].region
      private        = v.private
      network        = module.vpcs[k].self_link
      tunnel_command = try(module.bastions[k].tunnel_command, null)
      proxy_url      = v.private ? format("http://:%d", try(v.bastion_port, 8888)) : null
      sa             = local.sa_emails[k]
      annotations    = local.annotations[k]
      labels         = local.labels[k]
      vip            = try(google_compute_address.vip[k].address, null)
      }
    }
  })

  # Try to make this file generation dependent on *all* other modules
  depends_on = [
    module.sas,
    module.vpcs,
    module.restricted_apis_dns,
    module.bastions,
    module.public,
    module.private,
    local_file.kubeconfigs,
    local_file.application_kustomizations,
    local_file.vpm_configs,
    local_file.f5xc_kustomizations,
    local_file.service_discovery_kustomizations,
  ]
}
