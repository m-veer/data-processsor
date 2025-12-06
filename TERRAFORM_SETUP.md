# Terraform Setup Guide

Complete guide for setting up and managing infrastructure with Terraform.

## Quick Start
```bash
# 1. Update terraform.tfvars
cd terraform
nano terraform.tfvars
# Change: project_id = "your-actual-project-id"

# 2. Initialize Terraform
terraform init

# 3. Preview changes
terraform plan

# 4. Apply changes
terraform apply
```

## Prerequisites

- Terraform >= 1.0
- gcloud CLI authenticated
- GCP project with billing enabled

## First-Time Setup

### 1. Authenticate with GCP
```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR-PROJECT-ID
```

### 2. Initialize Firestore
```bash
# Via gcloud (if available in your region)
gcloud firestore databases create --region=us-central1

# Or via Console
open https://console.cloud.google.com/firestore
# Select "Native Mode" and choose region
```

### 3. Configure Terraform
```bash
cd terraform

# Update terraform.tfvars
cat > terraform.tfvars <<EOF
project_id = "your-actual-project-id"
region = "us-central1"
EOF
```

### 4. Initialize and Apply
```bash
# Download providers
terraform init

# Preview changes
terraform plan

# Create infrastructure
terraform apply
```

## Multi-Environment Deployment

### Deploy to Different Environments
```bash
# Development
terraform apply -var-file="environments/dev.tfvars"

# Staging
terraform apply -var-file="environments/staging.tfvars"

# Production
terraform apply -var-file="environments/prod.tfvars"
```

## Common Commands
```bash
# Initialize
terraform init

# Format code
terraform fmt

# Validate configuration
terraform validate

# Plan changes
terraform plan

# Apply changes
terraform apply

# Show current state
terraform show

# List resources
terraform state list

# Destroy infrastructure
terraform destroy
```

## Outputs

After applying, get deployment information:
```bash
# Show all outputs
terraform output

# Get specific output
terraform output api_service_url

# Get GitHub Actions key
terraform output -raw github_actions_sa_key | base64 -d > github-key.json
```

## Troubleshooting

### Issue: APIs not enabled
```bash
# Manually enable APIs
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  pubsub.googleapis.com
```

### Issue: Firestore already exists
```bash
# Import existing Firestore
terraform import google_firestore_database.database "(default)"
```

### Issue: State locked
```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

## Remote State (Optional)

For team collaboration, store state in GCS:
```bash
# Create bucket
gsutil mb gs://your-project-terraform-state

# Update main.tf
terraform {
  backend "gcs" {
    bucket = "your-project-terraform-state"
    prefix = "terraform/state"
  }
}

# Reinitialize
terraform init -reconfigure
```

## Best Practices

1. Always run `terraform plan` before `apply`
2. Use version control for all `.tf` files
3. Never commit `.tfstate` files
4. Use remote state for teams
5. Use workspaces or separate state files for environments
6. Review plans carefully before applying

## Resources Created

- Pub/Sub Topic and Subscription
- Cloud Run Services (API and Worker)
- Service Accounts (3 total)
- IAM Bindings (8 total)
- Artifact Registry Repository
- Firestore Database
- Monitoring Alert Policy

Total: ~15-20 resources

---

For complete documentation, see [deploy.md](./deploy.md)