#!/bin/bash

# ---------------------------
# Cloud Run Live Log Tailing
# ---------------------------

# Load .env file
set -o allexport
source .env
set +o allexport

export SERVICE_NAME=$SERVICE_NAME
export REGION=$REGION

echo "🔧 Ensuring gRPC is available for gcloud logging tail..."
export CLOUDSDK_PYTHON_SITEPACKAGES=1

# Try installing grpcio if missing
pip3 list 2>/dev/null | grep grpcio > /dev/null
if [ $? -ne 0 ]; then
    echo "📦 Installing grpcio..."
    pip3 install grpcio --quiet
fi

echo "🚀 Tailing logs for Cloud Run service: $SERVICE_NAME"
echo "Press CTRL+C to stop."

gcloud beta logging tail \
    "resource.type=cloud_run_revision AND resource.labels.service_name=$SERVICE_NAME" \
    --project="$(gcloud config get-value project)" \
    --format="value(textPayload)"
