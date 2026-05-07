# Cloud Photo Gallery — SE 4220 Final Project

A cloud-native photo gallery application deployed on Google Cloud Platform using Terraform for infrastructure-as-code.

---

## Architecture

```
                          Internet
                             │
                             ▼
                    ┌─────────────────┐
                    │   Firewall      │
                    │ HTTP/HTTPS :80  │
                    │ SSH :22         │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Compute Engine │
                    │  e2-standard-2  │
                    │  34.45.29.10    │
                    │                 │
                    │  nginx :80      │
                    │  Node.js :3000  │
                    │  PM2            │
                    └────────┬────────┘
                             │ Private IP
              ┌──────────────┼──────────────┐
              │              │              │
    ┌─────────▼──────┐       │    ┌─────────▼──────┐
    │   Cloud SQL    │       │    │  Cloud Storage  │
    │   MySQL 8.0    │       │    │  Photo Bucket   │
    │ db-n1-standard │       │    │ project-4b061234│
    │ Private IP only│       │    │    -photos      │
    └────────────────┘       │    └────────────────┘
                             │
                    ┌────────▼────────┐
                    │   gallery-vpc   │
                    │  10.0.0.0/16    │
                    │  us-central1    │
                    └─────────────────┘
```

---

## GCP Resources

| Resource | Type | Spec |
|---|---|---|
| Compute Engine VM | `e2-standard-2` | 2 vCPU, 8 GB RAM |
| Cloud SQL | MySQL 8.0 | `db-n1-standard-1` |
| VPC Network | Custom | `10.0.0.0/16` |
| Cloud Storage | Standard | us-central1 |
| Service Account | Least-privilege | storage, cloudsql, logging |
| Firewall | HTTP/HTTPS/SSH | Tags: `gallery-server` |

---

## Prerequisites

- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- GCP project with billing enabled
- GitHub repository with the Gallery application code

---

## Setup Instructions

### 1. Authenticate

```bash
gcloud auth application-default login
```

### 2. Create GCS buckets

```bash
# Terraform state bucket
gsutil mb -p YOUR_PROJECT_ID -l us-central1 gs://YOUR_PROJECT_ID-tf-state

# Photo storage bucket
gsutil mb -p YOUR_PROJECT_ID -l us-central1 gs://YOUR_PROJECT_ID-photos
```

### 3. Configure backend

Edit `terraform/backend.tf` and replace the bucket name:

```hcl
terraform {
  backend "gcs" {
    bucket = "YOUR_PROJECT_ID-tf-state"
    prefix = "terraform/state"
  }
}
```

### 4. Create terraform.tfvars

Create `terraform/terraform.tfvars` (this file is gitignored):

```hcl
project_id     = "your-project-id"
region         = "us-central1"
zone           = "us-central1-a"
db_user        = "gallery_user"
db_password    = "YourSecurePassword123!"
db_name        = "photo_gallery"
session_secret = "a-very-long-secret-at-least-32-characters-here"
app_repo_url   = "https://github.com/YOUR_USERNAME/photogallery.git"
gcs_app_bucket = "your-project-id-photos"
```

### 5. Deploy

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 6. Make photo bucket public

```bash
gcloud storage buckets add-iam-policy-binding gs://YOUR_PROJECT_ID-photos \
  --member=allUsers \
  --role=roles/storage.objectViewer
```

### 7. Access the application

After `terraform apply` completes, the outputs will show:

```
application_url  = "http://<VM_IP>"
health_check_url = "http://<VM_IP>/health"
```

The VM startup script takes ~5 minutes to finish installing dependencies and starting the app.

---

## Terraform File Structure

```
terraform/
├── requirements.tf   # Provider version constraints (Google ~> 5.0)
├── backend.tf        # GCS remote state backend
├── variables.tf      # Input variables with validation rules
├── main.tf           # VPC, Cloud SQL, firewall, service account, IAM
├── app-deploy.tf     # Compute Engine VM and static IP
└── outputs.tf        # Application URL, DB connection, SSH command
```

---

## Destroy Infrastructure

```bash
cd terraform
terraform destroy
```

---

## Application Features

- User registration and login
- Photo upload to Google Cloud Storage
- Photo gallery with search
- Photo download
- Health check endpoint at `/health`
- Secure database connection via Cloud SQL private IP
- Session management with MySQL session store
