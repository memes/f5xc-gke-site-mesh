variable "prefix" {
  type = string
}

variable "project_id" {
  type = string
}

variable "clusters" {
  type = map(object({
    region       = string
    private      = bool
    bastion_port = number
  }))
}

variable "annotations" {
  type    = map(string)
  default = {}
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "bastion_proxy_container_image" {
  type    = string
  default = "ghcr.io/memes/terraform-google-private-bastion/forward-proxy:2.2.1"
}

variable "site_token" {
  type = string
}

variable "f5xc_app_namespace" {
  type = string
}
