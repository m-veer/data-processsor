/**
 * Terraform Variables
 * Define all configurable parameters for the infrastructure
 */

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "firestore_location" {
  description = "Location for Firestore database"
  type        = string
  default     = "us-central1"
}

variable "api_service_name" {
  description = "Name of the API Cloud Run service"
  type        = string
  default     = "data-processor-api"
}

variable "worker_service_name" {
  description = "Name of the Worker Cloud Run service"
  type        = string
  default     = "data-processor-worker"
}

variable "pubsub_topic_name" {
  description = "Name of the Pub/Sub topic"
  type        = string
  default     = "data-ingestion"
}

variable "pubsub_subscription_name" {
  description = "Name of the Pub/Sub subscription"
  type        = string
  default     = "data-ingestion-sub"
}

variable "artifact_registry_repository" {
  description = "Name of the Artifact Registry repository"
  type        = string
  default     = "data-processor"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "api_min_instances" {
  description = "Minimum number of API instances"
  type        = number
  default     = 0
}

variable "api_max_instances" {
  description = "Maximum number of API instances"
  type        = number
  default     = 100
}

variable "worker_min_instances" {
  description = "Minimum number of Worker instances"
  type        = number
  default     = 1
}

variable "worker_max_instances" {
  description = "Maximum number of Worker instances"
  type        = number
  default     = 50
}

variable "api_cpu" {
  description = "CPU allocation for API service"
  type        = string
  default     = "1000m"
}

variable "api_memory" {
  description = "Memory allocation for API service"
  type        = string
  default     = "512Mi"
}

variable "worker_cpu" {
  description = "CPU allocation for Worker service"
  type        = string
  default     = "2000m"
}

variable "worker_memory" {
  description = "Memory allocation for Worker service"
  type        = string
  default     = "1Gi"
}

variable "enable_public_access" {
  description = "Allow unauthenticated access to API (for testing)"
  type        = bool
  default     = true
}