#!/bin/bash

# Load .env file
set -o allexport
source .env
set +o allexport

PROJECT_ID=$PROJECT_ID
REGION=$REGION

echo "Importing existing GCP resources into Terraform state..."

# Service Accounts
terraform import google_service_account.cloud_run_sa "projects/$PROJECT_ID/serviceAccounts/cloud-run-service-account@$PROJECT_ID.iam.gserviceaccount.com" || true
terraform import google_service_account.github_actions "projects/$PROJECT_ID/serviceAccounts/github-actions-deployer@$PROJECT_ID.iam.gserviceaccount.com" || true

# Pub/Sub
terraform import google_pubsub_topic.data_ingestion "projects/$PROJECT_ID/topics/data-ingestion" || true
terraform import google_pubsub_subscription.data_ingestion_sub "projects/$PROJECT_ID/subscriptions/data-ingestion-sub" || true

# Artifact Registry
terraform import google_artifact_registry_repository.docker_repo "projects/$PROJECT_ID/locations/$REGION/repositories/data-processor" || true

# Cloud Run (only if they exist)
# terraform import google_cloud_run_service.api "projects/$PROJECT_ID/locations/$REGION/services/data-processor-api" || true
# terraform import google_cloud_run_service.worker "projects/$PROJECT_ID/locations/$REGION/services/data-processor-worker" || true
terraform import google_cloud_run_service.api "locations/$REGION/namespaces/$PROJECT_ID/services/data-processor-api" || true
terraform import google_cloud_run_service.worker "locations/$REGION/namespaces/$PROJECT_ID/services/data-processor-worker" || true

# Firestore (only if it exists)
terraform import google_firestore_database.database "(default)" || true

echo "Import complete! Run 'terraform plan' to verify."