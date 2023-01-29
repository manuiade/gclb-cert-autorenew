//-----------------------------------------------------------------------------
// outputs.tf - contains the values to export 
//-----------------------------------------------------------------------------

output "global_ip_address" {
  value = module.lb_cert_rotator.global_ip_address
}