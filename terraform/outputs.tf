/**
 * Terraform Outputs
 * Values that will be displayed after terraform apply
 */

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP Region"
  value       = var.region
}

output "api_service_url" {
  description = "URL of the API service - use this to test your deployment"
  value       = google_cloud_run_service.api.status[0].url
}

output "worker_service_name" {
  description = "Name of the worker service"
  value       = google_cloud_run_service.worker.name
}

output "pubsub_topic_id" {
  description = "Full ID of the Pub/Sub topic"
  value       = google_pubsub_topic.data_ingestion.id
}

output "pubsub_subscription_id" {
  description = "Full ID of the Pub/Sub subscription"
  value       = google_pubsub_subscription.data_ingestion_sub.id
}

output "artifact_registry_repository_url" {
  description = "URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker_repo.name}"
}

output "cloud_run_service_account" {
  description = "Email of the Cloud Run service account"
  value       = google_service_account.cloud_run_sa.email
}

output "github_actions_service_account" {
  description = "Email of the GitHub Actions service account"
  value       = google_service_account.github_actions.email
}

// output "github_actions_sa_key" {
//   description = "GitHub Actions service account key (base64 encoded)"
//   value       = google_service_account_key.github_actions_key.private_key
//   sensitive   = true
// }

// output "github_actions_key_instructions" {
//   description = "Instructions for using the GitHub Actions key"
//   value       = <<-EOT
//     To get the GitHub Actions service account key:
//     1. Run: terraform output -raw github_actions_sa_key | base64 -d
//     2. Copy the entire JSON output
//     3. Add it as GCP_SA_KEY secret in GitHub repository settings
//   EOT
// }

output "test_commands" {
  description = "Commands to test your deployment"
  value       = <<-EOT
    # Test health endpoint
    curl ${google_cloud_run_service.api.status[0].url}/health
    
    # Test JSON ingestion
    curl -X POST ${google_cloud_run_service.api.status[0].url}/ingest \
      -H 'Content-Type: application/json' \
      -d '{"tenant_id": "acme", "log_id": "test_001", "text": "User 555-0199 accessed the system"}'
    
    # Test TXT ingestion
    curl -X POST ${google_cloud_run_service.api.status[0].url}/ingest \
      -H 'Content-Type: text/plain' \
      -H 'X-Tenant-ID: beta_inc' \
      -d 'Alert from facility 555-1234'
  EOT
}

output "firestore_console_url" {
  description = "URL to view Firestore data"
  value       = "https://console.cloud.google.com/firestore/data?project=${var.project_id}"
}

output "cloud_run_console_url" {
  description = "URL to view Cloud Run services"
  value       = "https://console.cloud.google.com/run?project=${var.project_id}"
}

output "deployment_summary" {
  description = "Summary of deployed resources"
  value       = <<-EOT
    ====================================
    DEPLOYMENT SUMMARY
    ====================================
    Project: ${var.project_id}
    Region: ${var.region}
    Environment: ${var.environment}
    
    Services:
    - API: ${google_cloud_run_service.api.name}
    - Worker: ${google_cloud_run_service.worker.name}
    
    Pub/Sub:
    - Topic: ${google_pubsub_topic.data_ingestion.name}
    - Subscription: ${google_pubsub_subscription.data_ingestion_sub.name}
    
    API URL: ${google_cloud_run_service.api.status[0].url}
    
    Next Steps:
    1. Test the API using the commands in 'test_commands' output
    2. View Firestore data at the URL in 'firestore_console_url'
    3. Set up GitHub Actions using the service account key
    ====================================
  EOT
}