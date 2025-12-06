/**
 * Main Terraform Configuration for Data Processor
 * This file defines all GCP resources needed for the application
 */

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Optional: Store state in GCS bucket for team collaboration
  # Uncomment after creating the bucket
  # backend "gcs" {
  #   bucket = "your-project-id-terraform-state"
  #   prefix = "terraform/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "cloudbuild.googleapis.com",
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "firestore.googleapis.com",
    "containerregistry.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "artifactregistry.googleapis.com",
  ])

  service            = each.value
  disable_on_destroy = false
}

# Pub/Sub Topic for data ingestion
resource "google_pubsub_topic" "data_ingestion" {
  name = var.pubsub_topic_name

  message_retention_duration = "604800s" # 7 days

  depends_on = [google_project_service.required_apis]
}

# Pub/Sub Subscription
resource "google_pubsub_subscription" "data_ingestion_sub" {
  name  = var.pubsub_subscription_name
  topic = google_pubsub_topic.data_ingestion.name

  ack_deadline_seconds       = 600
  message_retention_duration = "604800s" # 7 days
  retain_acked_messages      = false

  expiration_policy {
    ttl = "" # Never expire
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  depends_on = [google_project_service.required_apis]
}

# Service Account for Cloud Run Services
resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-service-account"
  display_name = "Cloud Run Service Account"
  description  = "Service account for Cloud Run API and Worker services"

  depends_on = [google_project_service.required_apis]
}

# IAM roles for Cloud Run Service Account
resource "google_project_iam_member" "cloud_run_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "cloud_run_pubsub_subscriber" {
  project = var.project_id
  role    = "roles/pubsub.subscriber"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "cloud_run_firestore_user" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "docker_repo" {
  location      = var.region
  repository_id = var.artifact_registry_repository
  description   = "Docker repository for data processor services"
  format        = "DOCKER"

  depends_on = [google_project_service.required_apis]
}

# Cloud Run Service - API
resource "google_cloud_run_service" "api" {
  name     = var.api_service_name
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email

      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository}/${var.api_service_name}:latest"

        resources {
          limits = {
            cpu    = var.api_cpu
            memory = var.api_memory
          }
        }

        ports {
          container_port = 8080
        }

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "PUBSUB_TOPIC_ID"
          value = google_pubsub_topic.data_ingestion.name
        }
      }

      container_concurrency = 80
      timeout_seconds       = 60
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale"     = tostring(var.api_min_instances)
        "autoscaling.knative.dev/maxScale"     = tostring(var.api_max_instances)
        "run.googleapis.com/cpu-throttling"    = "true"
        "run.googleapis.com/startup-cpu-boost" = "true"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  depends_on = [
    google_project_service.required_apis,
    google_pubsub_topic.data_ingestion,
    google_artifact_registry_repository.docker_repo,
  ]

  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].image,
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
    ]
  }
}

# Cloud Run Service - Worker
resource "google_cloud_run_service" "worker" {
  name     = var.worker_service_name
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email

      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_registry_repository}/${var.worker_service_name}:latest"

        resources {
          limits = {
            cpu    = var.worker_cpu
            memory = var.worker_memory
          }
        }

        env {
          name  = "GCP_PROJECT_ID"
          value = var.project_id
        }

        env {
          name  = "PUBSUB_SUBSCRIPTION_ID"
          value = google_pubsub_subscription.data_ingestion_sub.name
        }
      }

      container_concurrency = 1
      timeout_seconds       = 600
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale"  = tostring(var.worker_min_instances)
        "autoscaling.knative.dev/maxScale"  = tostring(var.worker_max_instances)
        "run.googleapis.com/cpu-throttling" = "false"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  depends_on = [
    google_project_service.required_apis,
    google_pubsub_subscription.data_ingestion_sub,
    google_artifact_registry_repository.docker_repo,
  ]

  lifecycle {
    ignore_changes = [
      template[0].spec[0].containers[0].image,
      template[0].metadata[0].annotations["run.googleapis.com/client-name"],
      template[0].metadata[0].annotations["run.googleapis.com/client-version"],
    ]
  }
}

# IAM policy to allow unauthenticated access to API (for testing)
resource "google_cloud_run_service_iam_member" "api_public_access" {
  count    = var.enable_public_access ? 1 : 0
  service  = google_cloud_run_service.api.name
  location = google_cloud_run_service.api.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Firestore Database (Native mode)
resource "google_firestore_database" "database" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.firestore_location
  type        = "FIRESTORE_NATIVE"

  depends_on = [google_project_service.required_apis]
}

# Service Account for GitHub Actions
resource "google_service_account" "github_actions" {
  account_id   = "github-actions-deployer"
  display_name = "GitHub Actions Deployer"
  description  = "Service account for GitHub Actions CI/CD"

  depends_on = [google_project_service.required_apis]
}

// # IAM roles for GitHub Actions Service Account
// resource "google_project_iam_member" "github_actions_roles" {
//   for_each = toset([
//     "roles/run.admin",
//     "roles/storage.admin",
//     "roles/cloudbuild.builds.builder",
//     "roles/iam.serviceAccountUser",
//     "roles/pubsub.admin",
//     "roles/serviceusage.serviceUsageAdmin",
//     "roles/artifactregistry.admin",
//   ])

//   project = var.project_id
//   role    = each.value
//   member  = "serviceAccount:${google_service_account.github_actions.email}"
// }

// # Service Account Key for GitHub Actions
// resource "google_service_account_key" "github_actions_key" {
//   service_account_id = google_service_account.github_actions.name
// }

# Cloud Monitoring Alert Policy
resource "google_monitoring_alert_policy" "high_error_rate" {
  display_name = "Cloud Run High Error Rate"
  combiner     = "OR"
  conditions {
    display_name = "Error rate > 5%"
    condition_threshold {
      filter          = "resource.type = \"cloud_run_revision\" AND metric.type = \"run.googleapis.com/request_count\" AND metric.label.response_code_class = \"5xx\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5
      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = []

  depends_on = [google_project_service.required_apis]
}