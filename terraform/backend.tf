# Remote state stored in GCS — bucket must exist before `terraform init`.
# Create the bucket manually first:
#   gsutil mb -p YOUR_PROJECT_ID -l us-central1 gs://YOUR_PROJECT_ID-tf-state
#
# Then run:
#   terraform init \
#     -backend-config="bucket=YOUR_PROJECT_ID-tf-state"
#
# Or edit the bucket value below and run `terraform init`.

terraform {
  backend "gcs" {
    bucket = "REPLACE_WITH_YOUR_TF_STATE_BUCKET"
    prefix = "terraform/state"
  }
}
