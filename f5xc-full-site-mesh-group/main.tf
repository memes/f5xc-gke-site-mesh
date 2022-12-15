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
  labels      = merge({}, local.foundations.labels)
  annotations = merge({
    "community.f5.com/provisioner" = "terraform"
  }, local.foundations.annotations)
}

# Create a virtual site that matches on a label common to all clusters in the demo.
resource "volterra_virtual_site" "group" {
  name        = local.foundations.prefix
  namespace   = "shared"
  description = "F5XC GKE Full Site Mesh demo"
  annotations = local.annotations
  labels      = local.labels
  site_selector {
    expressions = [
      join(",", [for k, v in local.foundations.labels : format("%s=%s", k, v)])
    ]
  }
  site_type = "CUSTOMER_EDGE"
}

resource "volterra_site_mesh_group" "group" {
  name        = local.foundations.prefix
  namespace   = "system"
  description = "F5XC GKE Full Site Mesh demo"
  annotations = local.annotations
  labels      = local.labels
  full_mesh {
    data_plane_mesh = true
  }
  virtual_site {
    name      = volterra_virtual_site.group.name
    namespace = volterra_virtual_site.group.namespace
  }
}
