//-----------------------------------------------------------------------------
// main.tf module call
//-----------------------------------------------------------------------------


module "lb_cert_rotator" {
    source = "./modules/load-balancer"
    project_id = var.project_id
    gcp_region = var.gcp_region
    service_account = var.service_account
    bucket_name = var.bucket_name
    load_balancer = var.load_balancer
    default_domain = var.default_domain
    domain_list = var.domain_list
}