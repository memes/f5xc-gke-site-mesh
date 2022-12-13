# This file contains generated file resources

resource "local_file" "public_kubeconfigs" {
  for_each             = module.public
  filename             = format("%s/../generated/%s/kubeconfig.yaml", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content = templatefile("${path.module}/templates/kubeconfig.yaml", {
    name     = each.value.name
    ca_cert  = each.value.ca_certificate
    endpoint = format("https://%s", each.value.endpoint)
  })
}

# MEmes' private GKE module includes a kubeconfig output
resource "local_file" "private_kubeconfigs" {
  for_each             = module.private
  filename             = format("%s/../generated/%s/kubeconfig.yaml", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content              = each.value.kubeconfig
}

resource "local_file" "echoserver_kustomizations" {
  for_each             = merge(module.public, module.private)
  filename             = format("%s/../generated/%s/echoserver/kustomization.yaml", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content = templatefile("${path.module}/templates/echoserver/kustomization.yaml", {
    cluster = each.key
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
    token     = var.site_token
    labels = {
      f5xc-full-site-mesh-group = var.prefix
    }
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
  content              = templatefile("${path.module}/templates/f5xc-site/kustomization.yaml", {})
}

resource "local_file" "service_discovery_kustomizations" {
  for_each             = merge(module.public, module.private)
  filename             = format("%s/../generated/%s/service-discovery/kustomization.yaml", path.module, each.key)
  file_permission      = "0644"
  directory_permission = "0755"
  content = templatefile("${path.module}/templates/service-discovery/kustomization.yaml", {
    name = local.resource_names[each.key]
  })
}

resource "local_file" "json" {
  filename             = "${path.module}/../generated/foundations.json"
  file_permission      = "0644"
  directory_permission = "0755"
  content = jsonencode({
    prefix = var.prefix
    clusters = { for k, v in var.clusters : k => {
      name           = local.resource_names[k]
      private        = v.private
      network        = module.vpcs[k].self_link
      subnet         = module.vpcs[k].subnets[v.region]
      tunnel_command = try(replace(module.bastions[k].tunnel_command, "localhost:8888", format("localhost:%d", 8888 + index(keys(var.clusters), k))), null)
      sa             = local.sa_emails[k]
      ca_cert        = try(module.public[k].ca_certificate, module.private[k].ca_cert)
      endpoint       = try(format("https://%s", module.public[k].endpoint), module.private[k].endpoint_url)
  } } })

  # Try to make this file generation dependent on *all* other modules
  depends_on = [
    module.sas,
    module.vpcs,
    module.restricted_apis_dns,
    module.bastions,
    module.public,
    module.private,
    local_file.public_kubeconfigs,
    local_file.private_kubeconfigs,
    local_file.echoserver_kustomizations,
    local_file.vpm_configs,
    local_file.f5xc_kustomizations,
    local_file.service_discovery_kustomizations,
  ]
}
