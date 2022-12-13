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
  prefix = lookup(jsondecode(file(var.foundations_json)), "prefix")
}

# Create a virtual site that matches on a label common to all clusters in the demo.
resource "volterra_virtual_site" "group" {
  name        = local.prefix
  namespace   = "shared"
  description = "F5XC GKE Full Site Mesh demo"
  site_selector {
    expressions = [
      format("f5xc-full-site-mesh-group = %s", local.prefix)
    ]
  }
  site_type = "CUSTOMER_EDGE"
}

resource "volterra_site_mesh_group" "group" {
  name        = local.prefix
  namespace   = "system"
  description = "F5XC GKE Full Site Mesh demo"
  full_mesh {
    data_plane_mesh = true
  }
  virtual_site {
    name      = volterra_virtual_site.group.name
    namespace = volterra_virtual_site.group.namespace
  }
}
