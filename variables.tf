//-----------------------------------------------------------------------------
// variables.tf - contains the definition of variables used by Terraform
//-----------------------------------------------------------------------------

variable "project_id" {
  type        = string
  description = "Project ID"
}

variable "gcp_region" {
  type        = string
  description = "GCP region"
}

variable "service_account" {
  type        = string
  description = "Service account email"
}

variable "bucket_name" {
  type        = string
  description = "Backend bucket name"
}

variable "load_balancer" {
  type        = string
  description = "Load balancer name"
}

variable "default_domain" {
  type        = string
  description = "Default domaind"
}

variable "domain_list" {
  type        = list(string)
  description = "Domain list"
  default = []
}