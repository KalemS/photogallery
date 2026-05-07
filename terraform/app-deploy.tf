# ── Static external IP ────────────────────────────────────────────────────────
resource "google_compute_address" "gallery_ip" {
  name   = "gallery-static-ip"
  region = var.region
}

# ── Compute Engine VM (e2-standard-2) ────────────────────────────────────────
resource "google_compute_instance" "gallery_vm" {
  name         = "photo-gallery-vm"
  machine_type = "e2-standard-2"
  zone         = var.zone

  tags = ["gallery-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id

    access_config {
      nat_ip = google_compute_address.gallery_ip.address
    }
  }

  # Use the app service account so GCS and Cloud SQL access work without key files
  service_account {
    email  = google_service_account.gallery_sa.email
    scopes = ["cloud-platform"]
  }

  # Startup script reads these metadata keys to build the .env file
  metadata = {
    db_host        = google_sql_database_instance.main.private_ip_address
    db_user        = var.db_user
    db_password    = var.db_password
    db_name        = var.db_name
    gcs_bucket     = var.gcs_app_bucket
    session_secret = var.session_secret
    app_repo       = var.app_repo_url
  }

  metadata_startup_script = file("${path.module}/../startup-script.sh")

  depends_on = [
    google_sql_database_instance.main,
    google_sql_user.gallery_user,
    google_service_account.gallery_sa,
    google_project_iam_member.sa_storage_object_admin,
    google_project_iam_member.sa_cloudsql_client,
  ]
}
