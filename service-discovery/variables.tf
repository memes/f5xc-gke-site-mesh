variable "foundations_json" {
  type    = string
  default = "../generated/foundations.json"
}

variable "kubeconfig" {
  type = string
}

variable "key" {
  type = string
}

variable "service_account" {
  type = string
}

variable "secret_name" {
  type = string
}

variable "secret_namespace" {
  type = string
}
