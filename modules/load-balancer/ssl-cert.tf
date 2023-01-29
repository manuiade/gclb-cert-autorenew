//-----------------------------------------------------------------------------
// ssl-certs.tf - creates all the infrastructure components to dynamically
// rotate ssl certificates based on new domains definition
//-----------------------------------------------------------------------------

// Creates a dummy certificate to setup the HTTP/S Load Balancer
resource "google_compute_managed_ssl_certificate" "default_ssl_cert" {
  name    = "${var.project_id}-default-domain"
  project = var.project_id
  type    = "MANAGED"
  managed {
    domains = [var.default_domain]
  }
}

// Create the bucket hosting the Cloud Function source code for SSL rotation
resource "google_storage_bucket" "source_code_bucket" {
  name          = "${var.project_id}-ssl-rot-bucket"
  location      = "EU"
  force_destroy = true
  project       = var.project_id
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
}

// Upload source code to GCS bucket
resource "google_storage_bucket_object" "source_code_object" {
  bucket = google_storage_bucket.source_code_bucket.name
  name   = "source-code/ssl-cert-rotator.zip"
  source = "${path.module}/../../static/cert-rotator-code/ssl-cert-rotator.zip"
}

// Creates/updates the cloud function based on the last domain and ssl certificates list
resource "google_cloudfunctions_function" "cert_rotator_function" {
  name                  = "ssl-cert-rotator"
  project               = var.project_id
  region                = var.gcp_region
  runtime               = "python39"
  service_account_email = google_service_account.cert_rotator_sa.email
  source_archive_bucket = google_storage_bucket.source_code_bucket.name
  source_archive_object = "source-code/ssl-cert-rotator.zip"
  timeout               = 120
  trigger_http          = true
  available_memory_mb   = 128
  entry_point           = "rotate_certs"
  environment_variables = {
    "_PROJECT_ID" : "${var.project_id}",
    "_GCP_REGION" : "${var.gcp_region}",
    "_CS_JOB_ID" : "${local.cs_job_id}",
    "_CHUNK_SIZE" : "${local.chunk_size}",
    "_TARGET_HTTPS_PROXY" : "${google_compute_target_https_proxy.https.name}",
    "_NEW_DOMAIN_LIST" : "${local.new_domain_list_string}",
    "_NEW_CERTS_LIST" : "${local.new_certs_self_link_list}",
    "_FIXED_CERTS_LIST" : "${google_compute_managed_ssl_certificate.default_ssl_cert.name}"
  }
  ingress_settings = "ALLOW_ALL"
  max_instances    = 1
}

// Grant SA invoke permission to cloud function
resource "google_cloudfunctions_function_iam_member" "cert_rotator_function_invoke" {
  project = var.project_id
  region = var.gcp_region
  cloud_function = google_cloudfunctions_function.cert_rotator_function.name
  role = "roles/cloudfunctions.invoker"
  member = format("serviceAccount:%s", google_service_account.cert_rotator_sa.email)
}

// Creates/update the Cloud Scheduler Job which periodically calls the Function for the certificate rotation
resource "google_cloud_scheduler_job" "cert_rotator_job" {
  name      = local.cs_job_id
  schedule  = "*/5 * * * *"
  time_zone = "Europe/Rome"
  project   = var.project_id
  region    = var.gcp_region
  http_target {
    http_method = "GET"
    uri         = google_cloudfunctions_function.cert_rotator_function.https_trigger_url
    oidc_token {
      service_account_email = google_service_account.cert_rotator_sa.email
    }
  }
}