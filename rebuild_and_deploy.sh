#!/bin/bash
set -e

# Load .env file
set -o allexport
source .env
set +o allexport

export API_URL=$API_URL
export PROJECT_ID=$PROJECT_ID
export REGION=$REGION

echo "🔨 Rebuilding Docker images..."

# Build API
cd api
echo "Building API..."
gcloud builds submit --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/data-processor/data-processor-api:latest .

# Build Worker  
cd ../worker
echo "Building Worker..."
gcloud builds submit --tag ${REGION}-docker.pkg.dev/${PROJECT_ID}/data-processor/data-processor-worker:latest .

echo "✅ Images built successfully"

# Verify images
echo "📦 Verifying images..."
gcloud artifacts docker images list ${REGION}-docker.pkg.dev/${PROJECT_ID}/data-processor

echo "🚀 Deploying API..."
gcloud run deploy data-processor-api \
  --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/data-processor/data-processor-api:latest \
  --platform=managed \
  --region=${REGION} \
  --allow-unauthenticated \
  --set-env-vars="GCP_PROJECT_ID=${PROJECT_ID},PUBSUB_TOPIC_ID=data-ingestion" \
  --memory=512Mi \
  --cpu=1 \
  --max-instances=10 \
  --timeout=60 \
  --port=8080

echo "🚀 Deploying Worker..."
gcloud run deploy data-processor-worker \
  --image=${REGION}-docker.pkg.dev/${PROJECT_ID}/data-processor/data-processor-worker:latest \
  --platform=managed \
  --region=${REGION} \
  --no-allow-unauthenticated \
  --set-env-vars="GCP_PROJECT_ID=${PROJECT_ID},PUBSUB_SUBSCRIPTION_ID=data-ingestion-sub" \
  --memory=1Gi \
  --cpu=2 \
  --max-instances=5 \
  --min-instances=1 \
  --timeout=600

# Get API URL
API_URL=$(gcloud run services describe data-processor-api --region=${REGION} --format='value(status.url)')

echo ""
echo "✅ Deployment Complete!"
echo "API URL: $API_URL"
echo ""
echo "Test with:"
echo "curl $API_URL/health"