🚀 Complete Initial Setup Guide
Let me walk you through the EXACT steps to get your application running from scratch!
Step 1: Create GCP Project
bash# 1. Go to GCP Console
open https://console.cloud.google.com

# 2. Create a new project (or use existing)
# Click "Select a project" → "New Project"
# Project name: data-processor
# Note down the Project ID (e.g., data-processor-123456)

# 3. Enable billing for the project
# Go to: Billing → Link a billing account
Step 2: Setup Local Environment
bash# 1. Install required tools (if not already installed)

# Install gcloud CLI (macOS)
brew install --cask google-cloud-sdk

# Install Terraform
brew install terraform

# Install Docker Desktop
brew install --cask docker

# 2. Authenticate with GCP
gcloud auth login

# 3. Set your project
export PROJECT_ID="your-project-id"  # Use the one you created
gcloud config set project $PROJECT_ID

# 4. Set application default credentials
gcloud auth application-default login
Step 3: Create Project Structure Locally
bash# 1. Create main directory
mkdir -p ~/data-processor
cd ~/data-processor

# 2. Create all subdirectories
mkdir -p api/tests
mkdir -p worker/tests
mkdir -p terraform/environments
mkdir -p .github/workflows

# 3. Verify structure
tree -L 2
# Should show:
# .
# ├── api
# │   └── tests
# ├── worker
# │   └── tests
# ├── terraform
# │   └── environments
# └── .github
#     └── workflows
Step 4: Copy All Files
Now copy each file I provided into the correct location. Here's a quick reference:
bash# Root files
touch README.md architecture.md deploy.md TERRAFORM_SETUP.md
touch .gitignore Makefile deploy.sh

# API files
touch api/Dockerfile api/main.py api/requirements.txt
touch api/tests/test_main.py

# Worker files
touch worker/Dockerfile worker/main.py worker/requirements.txt
touch worker/tests/test_main.py

# Terraform files
touch terraform/main.tf terraform/variables.tf terraform/outputs.tf
touch terraform/terraform.tfvars
touch terraform/environments/dev.tfvars
touch terraform/environments/staging.tfvars
touch terraform/environments/prod.tfvars

# GitHub workflows
touch .github/workflows/terraform-deploy.yml
touch .github/workflows/deploy-api.yml
touch .github/workflows/deploy-worker.yml
touch .github/workflows/deploy.yml

# Make deploy.sh executable
chmod +x deploy.sh
Now paste the content from each file I provided above into these files.
Step 5: Configure Your Project ID
bash# Edit terraform.tfvars
cd terraform
nano terraform.tfvars

# Change line 4 to your actual project ID:
# FROM: project_id = "your-gcp-project-id"
# TO:   project_id = "data-processor-123456"  # Your actual project ID

# Save and exit (Ctrl+X, Y, Enter)
Step 6: Initialize Firestore (One-Time)
bash# Option 1: Via gcloud (easiest)
gcloud firestore databases create --region=us-central1

# Option 2: Via Console (if above fails)
open "https://console.cloud.google.com/firestore?project=$PROJECT_ID"
# Click "Select Native Mode"
# Choose location: us-central1
# Click "Create Database"
Step 7: Enable Required APIs
bashgcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    pubsub.googleapis.com \
    firestore.googleapis.com \
    containerregistry.googleapis.com \
    artifactregistry.googleapis.com \
    iam.googleapis.com
Step 8: Deploy with Terraform
bash# 1. Navigate to terraform directory
cd ~/data-processor/terraform

# 2. Initialize Terraform (downloads providers)
terraform init

# Output should show:
# Terraform has been successfully initialized!

# 3. Preview what will be created
terraform plan

# Review the output - should show ~15-20 resources to be created

# 4. Apply the infrastructure
terraform apply

# Type 'yes' when prompted
# Wait 5-10 minutes for completion
Step 9: Build and Deploy Docker Images
bash# 1. Configure Docker for Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# 2. Build API image
cd ~/data-processor/api
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/data-processor/data-processor-api:latest .

# 3. Push API image
docker push us-central1-docker.pkg.dev/$PROJECT_ID/data-processor/data-processor-api:latest

# 4. Build Worker image
cd ~/data-processor/worker
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/data-processor/data-processor-worker:latest .

# 5. Push Worker image
docker push us-central1-docker.pkg.dev/$PROJECT_ID/data-processor/data-processor-worker:latest

# 6. Update Cloud Run services to use new images
cd ~/data-processor/terraform
terraform apply -auto-approve
Step 10: Get Your API URL and Test
bash# 1. Get API URL
cd ~/data-processor/terraform
export API_URL=$(terraform output -raw api_service_url)
echo "Your API URL: $API_URL"

# 2. Test health endpoint
curl $API_URL/health

# Expected output:
# {"status":"healthy","timestamp":"2024-...","pubsub_topic":"..."}

# 3. Test JSON ingestion
curl -X POST $API_URL/ingest \
  -H 'Content-Type: application/json' \
  -d '{
    "tenant_id": "acme",
    "log_id": "test_001",
    "text": "User 555-0199 accessed the system"
  }'

# Expected output:
# {"status":"accepted","tenant_id":"acme","log_id":"test_001",...}

# 4. Test TXT ingestion
curl -X POST $API_URL/ingest \
  -H 'Content-Type: text/plain' \
  -H 'X-Tenant-ID: beta_inc' \
  -d 'Emergency alert from facility 555-1234'

# Expected output:
# {"status":"accepted","tenant_id":"beta_inc",...}
Step 11: Verify Data in Firestore
bash# Wait 30 seconds for processing
sleep 30

# Open Firestore Console
open "https://console.cloud.google.com/firestore/data?project=$PROJECT_ID"

# You should see:
# tenants/
#   ├── acme/
#   │   └── processed_logs/
#   │       └── test_001/
#   └── beta_inc/
#       └── processed_logs/
#           └── [auto-generated-id]/
🎉 Success! Your Application is Running!

Optional: Setup GitHub CI/CD
If you want automatic deployments on push:
bash# 1. Initialize git repository
cd ~/data-processor
git init
git add .
git commit -m "Initial commit"

# 2. Create GitHub repository
# Go to: https://github.com/new
# Repository name: data-processor
# Keep it private
# Don't initialize with README

# 3. Push to GitHub
git remote add origin https://github.com/YOUR_USERNAME/data-processor.git
git branch -M main
git push -u origin main

# 4. Get service account key for GitHub Actions
cd terraform
terraform output -raw github_actions_sa_key | base64 -d > github-key.json

# 5. Add GitHub Secrets
# Go to: https://github.com/YOUR_USERNAME/data-processor/settings/secrets/actions
# Add two secrets:
#   - GCP_PROJECT_ID: your-project-id
#   - GCP_SA_KEY: (paste content of github-key.json)

# 6. Push again to trigger deployment
git push origin main

# Watch deployment at:
# https://github.com/YOUR_USERNAME/data-processor/actions

Quick Verification Checklist
bash# ✅ Check all services are running
gcloud run services list --region=us-central1

# Expected output:
# data-processor-api      us-central1  https://...
# data-processor-worker   us-central1  https://...

# ✅ Check Pub/Sub
gcloud pubsub topics list
gcloud pubsub subscriptions list

# ✅ Check logs
gcloud run services logs read data-processor-api --region=us-central1 --limit=10
gcloud run services logs read data-processor-worker --region=us-central1 --limit=10

# ✅ Test API again
curl $API_URL/health

Using the Makefile (Easier!)
Once setup is complete, you can use the Makefile for common operations:
bash# Show all available commands
make help

# Deploy to different environments
make deploy-dev
make deploy-staging
make deploy-prod

# View logs
make logs-api
make logs-worker

# Run tests
make test

# Check status
make status

# Quick test
make quick-test

Troubleshooting
Issue: "Permission Denied"
bash# Add yourself as owner
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:YOUR_EMAIL@gmail.com" \
  --role="roles/owner"
Issue: "API not enabled"
bash# Enable all APIs
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  pubsub.googleapis.com \
  firestore.googleapis.com \
  artifactregistry.googleapis.com
Issue: Docker build fails
bash# Make sure Docker Desktop is running
open -a Docker

# Verify Docker is running
docker ps
Issue: Terraform fails
bash# Clean and retry
cd terraform
rm -rf .terraform .terraform.lock.hcl
terraform init
terraform plan

Next Steps

✅ Application is running
✅ Test all endpoints
✅ Check Firestore data
📹 Record video walkthrough
📝 Update README with your specific details
🚀 Submit for FinQore application


Quick Reference
bash# Your API URL
echo $API_URL

# View all resources
cd ~/data-processor/terraform
terraform output

# View logs
make logs

# Test API
make quick-test

# Deploy updates
make deploy-prod
You're all set! Your production-grade data processor is now live on GCP! 🎉