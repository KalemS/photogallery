output "application_url" {
  description = "Public URL of the Gallery application"
  value       = "http://${google_compute_address.gallery_ip.address}"
}

output "health_check_url" {
  description = "Health check endpoint"
  value       = "http://${google_compute_address.gallery_ip.address}/health"
}

output "vm_external_ip" {
  description = "Static external IP of the Compute Engine VM"
  value       = google_compute_address.gallery_ip.address
}

output "vm_ssh_command" {
  description = "gcloud command to SSH into the VM"
  value       = "gcloud compute ssh ${google_compute_instance.gallery_vm.name} --zone=${var.zone} --project=${var.project_id}"
}

output "db_connection_name" {
  description = "Cloud SQL connection name (PROJECT:REGION:INSTANCE)"
  value       = google_sql_database_instance.main.connection_name
}

output "db_private_ip" {
  description = "Cloud SQL private IP address"
  value       = google_sql_database_instance.main.private_ip_address
}

output "service_account_email" {
  description = "Service account email attached to the VM"
  value       = google_service_account.gallery_sa.email
}

output "startup_log_command" {
  description = "Command to tail the VM startup script log"
  value       = "gcloud compute ssh ${google_compute_instance.gallery_vm.name} --zone=${var.zone} --project=${var.project_id} -- 'sudo journalctl -u google-startup-scripts -f'"
}
