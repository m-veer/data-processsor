#!/bin/bash

# GCP Deployment Script for Data Processor
# This script sets up the entire infrastructure on GCP

set -e  # Exit on error

# Load .env file
set -o allexport
source .env
set +o allexport

# Configuration
PROJECT_ID=$PROJECT_ID
REGION=$REGION
TOPIC_ID=$TOPIC_ID
SUBSCRIPTION_ID=$SUBSCRIPTION_ID
API_SERVICE_NAME=$API_SERVICE_NAME
WORKER_SERVICE_NAME=$WORKER_SERVICE_NAME

echo "========================================="
echo "GCP Data Processor Deployment"
echo "========================================="
# echo "Project ID: $PROJECT_ID"
# echo "Region: $REGION"
echo ""

# Set project
echo "Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "Enabling required GCP APIs..."
gcloud services enable \
    cloudbuild.googleapis.com \
    run.googleapis.com \
    pubsub.googleapis.com \
    firestore.googleapis.com \
    containerregistry.googleapis.com

# Create Pub/Sub Topic
echo "Creating Pub/Sub topic..."
gcloud pubsub topics create $TOPIC_ID || echo "Topic already exists"

# Create Pub/Sub Subscription
echo "Creating Pub/Sub subscription..."
gcloud pubsub subscriptions create $SUBSCRIPTION_ID \
    --topic=$TOPIC_ID \
    --ack-deadline=600 \
    --message-retention-duration=7d || echo "Subscription already exists"

# Initialize Firestore (if not already done)
echo "Firestore should be initialized manually via Console if not done yet"
echo "Go to: https://console.cloud.google.com/firestore"
echo "Select 'Native Mode' and choose a region"
read -p "Press Enter once Firestore is initialized..."

# Build and deploy API service
echo "Building and deploying API service..."
cd api
gcloud builds submit --tag gcr.io/$PROJECT_ID/$API_SERVICE_NAME

gcloud run deploy $API_SERVICE_NAME \
    --image gcr.io/$PROJECT_ID/$API_SERVICE_NAME \
    --platform managed \
    --region $REGION \
    --allow-unauthenticated \
    --set-env-vars GCP_PROJECT_ID=$PROJECT_ID,PUBSUB_TOPIC_ID=$TOPIC_ID \
    --memory 512Mi \
    --cpu 1 \
    --max-instances 100 \
    --min-instances 0 \
    --timeout 60

cd ..

# Build and deploy Worker service
echo "Building and deploying Worker service..."
cd worker
gcloud builds submit --tag gcr.io/$PROJECT_ID/$WORKER_SERVICE_NAME

gcloud run deploy $WORKER_SERVICE_NAME \
    --image gcr.io/$PROJECT_ID/$WORKER_SERVICE_NAME \
    --platform managed \
    --region $REGION \
    --no-allow-unauthenticated \
    --set-env-vars GCP_PROJECT_ID=$PROJECT_ID,PUBSUB_SUBSCRIPTION_ID=$SUBSCRIPTION_ID \
    --memory 1Gi \
    --cpu 2 \
    --max-instances 50 \
    --min-instances 1 \
    --timeout 600

cd ..

# Get API URL
API_URL=$(gcloud run services describe $API_SERVICE_NAME --region $REGION --format 'value(status.url)')

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo "API URL: $API_URL"
echo ""
echo "Test with JSON:"
echo "curl -X POST $API_URL/ingest \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"tenant_id\": \"acme\", \"log_id\": \"123\", \"text\": \"User 555-0199 accessed the system\"}'"
echo ""
echo "Test with TXT:"
echo "curl -X POST $API_URL/ingest \\"
echo "  -H 'Content-Type: text/plain' \\"
echo "  -H 'X-Tenant-ID: beta_inc' \\"
echo "  -d 'User 555-0199 accessed the system'"
echo ""
echo "View logs:"
echo "API Logs: gcloud run services logs read $API_SERVICE_NAME --region $REGION"
echo "Worker Logs: gcloud run services logs read $WORKER_SERVICE_NAME --region $REGION"
echo ""
echo "View Firestore data:"
echo "https://console.cloud.google.com/firestore/data"