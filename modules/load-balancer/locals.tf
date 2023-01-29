//-----------------------------------------------------------------------------
// locals.tf - format variables for easier use in resource attributes
//-----------------------------------------------------------------------------


locals {

  // Required permissions for cloud function in order to perform cert rotation
  cert_rotator_custom_role_permissions = [
    "compute.targetHttpsProxies.get",
    "compute.targetHttpsProxies.list",
    "compute.targetHttpsProxies.setSslCertificates",
    "compute.sslCertificates.create",
    "compute.sslCertificates.delete",
    "compute.sslCertificates.get",
    "compute.sslCertificates.list",
    "cloudscheduler.jobs.pause"
  ]

  chunk_size = 100 // Max domains supported by a GCP-managed SSL certificate

  cs_job_id = "check-ssl-${sha1(join("", var.domain_list))}"

  chunked_new_domain_list = chunklist(var.domain_list, local.chunk_size)

  new_certs = flatten([
    for c in local.chunked_new_domain_list : {
      domains = c
      name    = "ssl-${sha1(join("", c))}"
    }
  ])

  new_certs_list           = { for s in local.new_certs : "${s.name}" => s }
  new_certs_self_link_list = join(",", [for k, v in local.new_certs_list : "${v.name}"])
  new_domain_list_string   = join(",", var.domain_list)
}