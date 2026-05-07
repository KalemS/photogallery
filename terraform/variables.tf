variable "project_id" {
  description = "GCP project ID"
  type        = string

  validation {
    condition     = length(var.project_id) > 0
    error_message = "project_id must not be empty."
  }
}

variable "region" {
  description = "GCP region for all resources"
  type        = string
  default     = "us-central1"

  validation {
    condition = contains([
      "us-central1", "us-east1", "us-east4", "us-west1", "us-west2",
      "europe-west1", "europe-west2", "europe-west3", "europe-west4",
      "asia-east1", "asia-northeast1", "asia-southeast1",
    ], var.region)
    error_message = "region must be a valid GCP region."
  }
}

variable "zone" {
  description = "GCP zone for the Compute Engine VM (must be within region)"
  type        = string
  default     = "us-central1-a"

  validation {
    condition     = length(var.zone) > 0
    error_message = "zone must not be empty."
  }
}

variable "db_user" {
  description = "MySQL database username"
  type        = string
  default     = "gallery_user"

  validation {
    condition     = length(var.db_user) >= 3
    error_message = "db_user must be at least 3 characters."
  }
}

variable "db_password" {
  description = "MySQL database password (sensitive)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 8
    error_message = "db_password must be at least 8 characters."
  }
}

variable "db_name" {
  description = "MySQL database name"
  type        = string
  default     = "photo_gallery"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter and contain only alphanumerics and underscores."
  }
}

variable "session_secret" {
  description = "Express session secret — minimum 32 characters (sensitive)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.session_secret) >= 32
    error_message = "session_secret must be at least 32 characters."
  }
}

variable "app_repo_url" {
  description = "GitHub repository URL for the Gallery application (used in VM startup script)"
  type        = string

  validation {
    condition     = can(regex("^https://github\\.com/.+/.+\\.git$", var.app_repo_url))
    error_message = "app_repo_url must be a valid GitHub HTTPS clone URL ending in .git"
  }
}

variable "gcs_app_bucket" {
  description = "GCS bucket name for photo storage (created in Project 4)"
  type        = string

  validation {
    condition     = length(var.gcs_app_bucket) >= 3
    error_message = "gcs_app_bucket must be at least 3 characters."
  }
}
