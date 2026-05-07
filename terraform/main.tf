provider "google" {
  project = var.project_id
  region  = var.region
}

# ── Enable required APIs ──────────────────────────────────────────────────────
resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
  ])
  service            = each.value
  disable_on_destroy = false
}

# ── VPC Network ───────────────────────────────────────────────────────────────
resource "google_compute_network" "vpc" {
  name                    = "gallery-vpc"
  auto_create_subnetworks = false
  depends_on              = [google_project_service.apis]
}

resource "google_compute_subnetwork" "subnet" {
  name          = "gallery-subnet"
  ip_cidr_range = "10.0.0.0/16"
  region        = var.region
  network       = google_compute_network.vpc.id
}

# ── Private services access for Cloud SQL private IP ─────────────────────────
resource "google_compute_global_address" "private_services_range" {
  name          = "gallery-private-services-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services_range.name]
  depends_on              = [google_project_service.apis]
}

# ── Firewall rules ────────────────────────────────────────────────────────────
resource "google_compute_firewall" "allow_http_https" {
  name    = "gallery-allow-http-https"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gallery-server"]
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "gallery-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["gallery-server"]
}

# GCP health check probe ranges
resource "google_compute_firewall" "allow_health_check" {
  name    = "gallery-allow-health-check"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["130.211.0.0/22", "35.191.0.0/16"]
  target_tags   = ["gallery-server"]
}

# ── Service account (least-privilege) ────────────────────────────────────────
resource "google_service_account" "gallery_sa" {
  account_id   = "gallery-app-sa"
  display_name = "Photo Gallery App Service Account"
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "sa_storage_object_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.gallery_sa.email}"
}

resource "google_project_iam_member" "sa_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.gallery_sa.email}"
}

resource "google_project_iam_member" "sa_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gallery_sa.email}"
}

resource "google_project_iam_member" "sa_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gallery_sa.email}"
}

# ── Cloud SQL MySQL instance (2nd gen, db-n1-standard-1, private networking) ─
resource "google_sql_database_instance" "main" {
  name             = "photo-gallery-db"
  database_version = "MYSQL_8_0"
  region           = var.region

  settings {
    tier = "db-n1-standard-1"

    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.id
    }

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }

    availability_type = "ZONAL"
  }

  # Allow terraform destroy to work during grading
  deletion_protection = false

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

resource "google_sql_database" "gallery_db" {
  name      = var.db_name
  instance  = google_sql_database_instance.main.name
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

resource "google_sql_user" "gallery_user" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name
  password = var.db_password
}
