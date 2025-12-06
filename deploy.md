# Deployment Guide

Complete guide to deploy the Data Processor application to Google Cloud Platform using Terraform.

## Prerequisites

### Required Tools

1. **Terraform** (>= 1.0)
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

2. **Google Cloud SDK**
   ```bash
   # macOS
   brew install --cask google-cloud-sdk
   
   # Linux
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   ```

3. **Docker** (for building images)
   ```bash
   # macOS
   brew install --cask docker
   
   # Linux
   sudo apt-get install docker.io
   ```

4. **Git**
   ```bash
   brew install git  # macOS
   sudo apt-get install git  # Linux
   ```

### GCP Setup

1. **Create GCP Project**
   ```bash
   # Set project ID (must be globally unique)
   export PROJECT_ID="your-unique-project-id"
   
   # Create project
   gcloud projects create $PROJECT_ID --name="Data Processor"
   
   # Set as default
   gcloud config set project $PROJECT_ID
   ```

2. **Enable Billing**
   ```bash
   # List billing accounts
   gcloud billing accounts list
   
   # Link billing (replace BILLING_ACCOUNT_ID)
   gcloud billing projects link $PROJECT_ID \
     --billing-account=BILLING_ACCOUNT_ID
   ```

3. **Authenticate**
   ```bash
   # Login to GCP
   gcloud auth login
   
   # Set application default credentials
   gcloud auth application-default login
   ```

## Deployment Methods

Choose one of three deployment methods based on your needs:

### Method 1: Local Terraform Deployment (Recommended for First Time)

**Time**: 30 minutes  
**Best for**: Understanding infrastructure, learning Terraform

#### Step 1: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/data-processor.git
cd data-processor
```

#### Step 2: Configure Terraform

```bash
cd terraform

# Update terraform.tfvars
cat > terraform.tfvars <<EOF
project_id = "$PROJECT_ID"
region = "us-central1"
firestore_location = "us-central1"
environment = "prod"
EOF
```

#### Step 3: Initialize Firestore

```bash
# Initialize Firestore (one-time setup)
gcloud firestore databases create --region=us-central1
```

#### Step 4: Initialize Terraform

```bash
# Download providers and modules
terraform init

# Expected output:
# Terraform has been successfully initialized!
```

#### Step 5: Preview Changes

```bash
# See what will be created
terraform plan

# Review the output carefully
# Should show ~15-20 resources to be created
```

#### Step 6: Apply Infrastructure

```bash
# Create infrastructure
terraform apply

# Type 'yes' when prompted

# Wait 5-10 minutes for completion
```

#### Step 7: Get Deployment Info

```bash
# View outputs
terraform output

# Get API URL
export API_URL=$(terraform output -raw api_service_url)
echo "API URL: $API_URL"
```

#### Step 8: Build and Deploy Docker Images

```bash
# Configure Docker for Artifact Registry
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and push API
cd ../api
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/data-processor/data-processor-api:latest .
docker push us-central1-docker.pkg.dev/$PROJECT_ID/data-processor/data-processor-api:latest

# Build and push Worker
cd ../worker
docker build -t us-central1-docker.pkg.dev/$PROJECT_ID/data-processor/data-processor-worker:latest .
docker push us-central1-docker.pkg.dev/$PROJECT_ID/data-processor/data-processor-worker:latest

# Update Cloud Run services
cd ../terraform
terraform apply -auto-approve
```

#### Step 9: Test Deployment

```bash
# Health check
curl $API_URL/health

# Test JSON ingestion
curl -X POST $API_URL/ingest \
  -H 'Content-Type: application/json' \
  -d '{
    "tenant_id": "test",
    "log_id": "001",
    "text": "Deployment test message"
  }'

# Should return 202 Accepted
```

#### Step 10: Verify in Firestore

```bash
# Wait 30 seconds for processing
sleep 30

# Open Firestore Console
open "https://console.cloud.google.com/firestore/data?project=$PROJECT_ID"

# You should see: tenants/test/processed_logs/001
```

---

### Method 2: Using Makefile (Fastest)

**Time**: 15 minutes  
**Best for**: Quick deployments, repeated use

#### Prerequisites

```bash
# Ensure Makefile is in project root
ls Makefile

# Install make if needed
brew install make  # macOS
sudo apt-get install make  # Linux
```

#### Deploy

```bash
# Initialize
make init

# Configure (edit terraform.tfvars first)
make plan

# Deploy everything
make apply

# Test
make test-integration
```

#### Common Commands

```bash
make help              # Show all commands
make deploy-dev        # Deploy to dev environment
make deploy-staging    # Deploy to staging
make deploy-prod       # Deploy to production
make logs-api          # View API logs
make logs-worker       # View worker logs
make status            # Check all services
```

---

### Method 3: GitHub Actions (Production CI/CD)

**Time**: 1 hour initial setup, then automatic  
**Best for**: Team development, continuous deployment

#### Step 1: Fork/Clone Repository

```bash
# Fork on GitHub or clone
git clone https://github.com/YOUR_USERNAME/data-processor.git
cd data-processor
```

#### Step 2: Create Service Account for GitHub Actions

```bash
# Create service account
gcloud iam service-accounts create github-actions-deployer \
  --display-name="GitHub Actions Deployer" \
  --project=$PROJECT_ID

# Get email
export SA_EMAIL="github-actions-deployer@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant permissions
for role in \
  roles/run.admin \
  roles/storage.admin \
  roles/cloudbuild.builds.builder \
  roles/iam.serviceAccountUser \
  roles/pubsub.admin \
  roles/serviceusage.serviceUsageAdmin \
  roles/artifactregistry.admin; do
  gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="$role"
done

# Create key
gcloud iam service-accounts keys create github-sa-key.json \
  --iam-account=$SA_EMAIL
```

#### Step 3: Add GitHub Secrets

Go to your GitHub repository:

1. **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**

Add these secrets:

| Name | Value |
|------|-------|
| `GCP_PROJECT_ID` | Your project ID |
| `GCP_SA_KEY` | Contents of `github-sa-key.json` |

```bash
# Get service account key content
cat github-sa-key.json
# Copy entire JSON output
```

#### Step 4: Initialize Firestore (One-time)

```bash
gcloud firestore databases create --region=us-central1
```

#### Step 5: Update Environment Files

```bash
# Edit terraform/environments/prod.tfvars
cat > terraform/environments/prod.tfvars <<EOF
project_id = "$PROJECT_ID"
region = "us-central1"
firestore_location = "us-central1"
environment = "prod"

api_service_name = "data-processor-api"
worker_service_name = "data-processor-worker"
pubsub_topic_name = "data-ingestion"
pubsub_subscription_name = "data-ingestion-sub"
artifact_registry_repository = "data-processor"

api_min_instances = 0
api_max_instances = 100
worker_min_instances = 1
worker_max_instances = 50

enable_public_access = true
EOF
```

#### Step 6: Commit and Push

```bash
# Add GitHub workflow
git add .github/workflows/terraform-deploy.yml
git add terraform/

# Commit
git commit -m "Add Terraform infrastructure and CI/CD"

# Push (triggers deployment!)
git push origin main
```

#### Step 7: Monitor Deployment

1. Go to GitHub repository
2. Click **Actions** tab
3. Watch the workflow run
4. Expected time: 10-15 minutes

#### Step 8: Get API URL

```bash
# After deployment completes
gh run view --log | grep "API URL"

# Or from GCP Console
gcloud run services describe data-processor-api \
  --region=us-central1 \
  --format='value(status.url)'
```

---

## Multi-Environment Setup

### Create Separate Projects

```bash
# Development
gcloud projects create your-project-dev

# Staging  
gcloud projects create your-project-staging

# Production
gcloud projects create your-project-prod
```

### Configure Environment Files

```bash
# terraform/environments/dev.tfvars
project_id = "your-project-dev"
environment = "dev"
api_max_instances = 10
worker_max_instances = 5

# terraform/environments/staging.tfvars
project_id = "your-project-staging"
environment = "staging"
api_max_instances = 50
worker_max_instances = 25

# terraform/environments/prod.tfvars
project_id = "your-project-prod"
environment = "prod"
api_max_instances = 100
worker_max_instances = 50
api_min_instances = 1  # Keep warm
```

### Deploy to Each Environment

```bash
# Development
terraform apply -var-file="environments/dev.tfvars"

# Staging
terraform apply -var-file="environments/staging.tfvars"

# Production
terraform apply -var-file="environments/prod.tfvars"
```

---

## Troubleshooting

### Issue: API not enabled

```bash
# Error: Error creating Topic: googleapi: Error 403

# Solution: Enable APIs manually
gcloud services enable \
  cloudbuild.googleapis.com \
  run.googleapis.com \
  pubsub.googleapis.com \
  firestore.googleapis.com
```

### Issue: Firestore already exists

```bash
# Error: Error creating Database: resource already exists

# Solution: Import existing database
terraform import google_firestore_database.database "(default)"
```

### Issue: Docker build fails

```bash
# Error: Cannot connect to Docker daemon

# Solution: Start Docker
open -a Docker  # macOS
sudo systemctl start docker  # Linux
```

### Issue: Permission denied

```bash
# Error: Permission denied on project

# Solution: Check IAM permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL@gmail.com"
```

### Issue: Terraform state locked

```bash
# Error: state file locked

# Solution: Wait or force unlock
terraform force-unlock LOCK_ID

# Or delete lock file (local state only)
rm terraform/.terraform/terraform.tfstate.lock.info
```

---

## Post-Deployment Checks

### 1. Verify Services

```bash
# Check Cloud Run services
gcloud run services list --region=us-central1

# Expected:
# data-processor-api     us-central1  https://xxx.run.app
# data-processor-worker  us-central1  https://yyy.run.app
```

### 2. Test API

```bash
# Health check
curl $API_URL/health

# JSON ingestion
curl -X POST $API_URL/ingest \
  -H 'Content-Type: application/json' \
  -d '{"tenant_id": "test", "text": "Test message"}'
```

### 3. Check Pub/Sub

```bash
# List topics
gcloud pubsub topics list

# Check subscription
gcloud pubsub subscriptions describe data-ingestion-sub
```

### 4. Verify Firestore

```bash
# Open Firestore Console
open "https://console.cloud.google.com/firestore/data?project=$PROJECT_ID"

# Or list collections
gcloud firestore collections list
```

### 5. View Logs

```bash
# API logs
gcloud run services logs read data-processor-api \
  --region=us-central1 \
  --limit=50

# Worker logs
gcloud run services logs read data-processor-worker \
  --region=us-central1 \
  --limit=50
```

---

## Rollback

### Rollback to Previous Version

```bash
# List revisions
gcloud run revisions list \
  --service=data-processor-api \
  --region=us-central1

# Route traffic to previous revision
gcloud run services update-traffic data-processor-api \
  --to-revisions=data-processor-api-00001-abc=100 \
  --region=us-central1
```

### Rollback Terraform Changes

```bash
# Revert git commit
git revert HEAD

# Apply reverted configuration
terraform apply
```

---

## Cleanup

### Destroy All Resources

```bash
# WARNING: This deletes everything!
cd terraform
terraform destroy

# Or use Makefile
make destroy
```

### Selective Cleanup

```bash
# Remove specific resource
terraform destroy -target=google_cloud_run_service.api

# Remove Pub/Sub only
terraform destroy \
  -target=google_pubsub_topic.data_ingestion \
  -target=google_pubsub_subscription.data_ingestion_sub
```

---

## Cost Management

### Set Budget Alert

```bash
# Create budget
gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="Data Processor Budget" \
  --budget-amount=50 \
  --threshold-rule=percent=90
```

### Monitor Costs

```bash
# View costs
open "https://console.cloud.google.com/billing"

# Export to BigQuery
gcloud billing accounts export create \
  --billing-account=BILLING_ACCOUNT_ID \
  --dataset=YOUR_DATASET \
  --table=YOUR_TABLE
```

---

## Security Hardening

### Enable Authentication

```bash
# Update terraform.tfvars
enable_public_access = false

# Apply changes
terraform apply

# Now API requires authentication
curl $API_URL/ingest  # 403 Forbidden

# Test with auth
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  $API_URL/health
```

### Rotate Service Account Keys

```bash
# List keys
gcloud iam service-accounts keys list \
  --iam-account=$SA_EMAIL

# Delete old key
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=$SA_EMAIL

# Create new key
gcloud iam service-accounts keys create new-key.json \
  --iam-account=$SA_EMAIL

# Update GitHub secret
```

---

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Test API endpoints
3. ✅ Run load tests
4. ✅ Set up monitoring
5. ✅ Configure alerts
6. ✅ Enable authentication (production)
7. ✅ Document for team
8. ✅ Set up backup strategy

---

**Deployment complete! Your data processor is now running on GCP.** 🎉