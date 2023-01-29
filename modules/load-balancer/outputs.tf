//-----------------------------------------------------------------------------
// outputs.tf - contains the values to export to the root module
//-----------------------------------------------------------------------------

output "global_ip_address" {
  value = google_compute_global_address.global_ipv4.address
}