//-----------------------------------------------------------------------------
// load-balancer.tf - creates all the component to setup a Global external
// HTTP/S Load Balancer
//-----------------------------------------------------------------------------


// Creates a global external IPV4 address
resource "google_compute_global_address" "global_ipv4" {
  name = var.load_balancer
  ip_version = "IPV4"
  purpose    = ""
  project    = var.project_id
}

// Url map rule used to redirect incoming request to backend bucket.
resource "google_compute_url_map" "https" {
  name            = var.load_balancer
  project         = var.project_id
  default_service = google_compute_backend_bucket.backend_bucket.self_link
}

// A url map used for redirect http request to https load balancer
resource "google_compute_url_map" "http" {
  name    = "${var.load_balancer}-http"
  project = var.project_id
  default_url_redirect {
    host_redirect          = ""
    https_redirect         = true
    path_redirect          = ""
    prefix_redirect        = ""
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}


// Definition of the target https proxy which terminates SSL connections and forwards them to the https url map
resource "google_compute_target_https_proxy" "https" {
  name             = var.load_balancer
  project          = var.project_id
  proxy_bind       = false
  quic_override    = "ENABLE"
  ssl_certificates = [google_compute_managed_ssl_certificate.default_ssl_cert.self_link]
  url_map          = google_compute_url_map.https.self_link

  // SSL certificates modification are ignored since the rotation script will dynamically change them
  lifecycle {
    ignore_changes = [
      ssl_certificates,
    ]
  }
}

// Definition of target http proxy which forward incoming http request to the http url map
resource "google_compute_target_http_proxy" "http" {
  name       = "${var.load_balancer}-http"
  project    = var.project_id
  proxy_bind = false
  url_map    = google_compute_url_map.http.self_link
}


// The https forwaring rule which accept https requests on the global external IP
resource "google_compute_global_forwarding_rule" "https" {
  name                  = var.load_balancer
  project               = var.project_id
  target                = google_compute_target_https_proxy.https.self_link
  ip_address            = google_compute_global_address.global_ipv4.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "443-443"
}

// The http forwaring rule which accept http requests on the global external IP
resource "google_compute_global_forwarding_rule" "http" {
  name                  = "${var.load_balancer}-http"
  project               = var.project_id
  target                = google_compute_target_http_proxy.http.self_link
  ip_address            = google_compute_global_address.global_ipv4.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL"
  port_range            = "80-80"
}

