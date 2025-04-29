//-----------------------------------------------------------------------------
// backend-bucket.tf - creates backend buckets for static response
//-----------------------------------------------------------------------------


// Creates GCS bucket
resource "google_storage_bucket" "backend_bucket" {
  name                        = var.bucket_name
  location                    = var.gcp_region
  project                     = var.project_id
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true

  website {
    main_page_suffix = "backend-response.png"
  }
}


// Upload static asset to GCS bucket
resource "google_storage_bucket_object" "bucket_object" {
  bucket = google_storage_bucket.backend_bucket.name
  name   = "backend-response.png"
  source = "${path.module}/../../static/backend-response.png"
}

// Make bucket public
resource "google_storage_bucket_iam_member" "bucket_public" {
  bucket = google_storage_bucket.backend_bucket.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

// Creates the backend bucket
resource "google_compute_backend_bucket" "backend_bucket" {
  name        = var.bucket_name
  project     = var.project_id
  bucket_name = google_storage_bucket.backend_bucket.name
}
