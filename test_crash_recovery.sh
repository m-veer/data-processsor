#!/bin/bash

# Load .env file
set -o allexport
source .env
set +o allexport

export API_URL=$API_URL
export PROJECT_ID=$PROJECT_ID
export REGION=$REGION

echo "========================================"
echo "🧪 CRASH RECOVERY TEST - 5 Retries"
echo "========================================"
echo ""

# Send crash test message
echo "📤 Sending CRASH_TEST message..."
RESPONSE=$(curl -s -X POST $API_URL/ingest \
  -H 'Content-Type: application/json' \
  -d '{
    "tenant_id": "crash_recovery_demo",
    "log_id": "retry_demo_001",
    "text": "CRASH_TEST - Will fail 5 times then succeed"
  }')

echo "Response: $RESPONSE"
echo ""

# Extract log_id from response
LOG_ID=$(echo $RESPONSE | grep -o '"log_id":"[^"]*"' | cut -d'"' -f4)
echo "Tracking log_id: $LOG_ID"
echo ""

# Monitor retries
echo "🔍 Monitoring worker logs (this will take ~5 minutes)..."
echo "Expected timeline:"
echo "  • Attempt 1: Now (immediate)"
echo "  • Attempt 2: +10 seconds"
echo "  • Attempt 3: +20 seconds"
echo "  • Attempt 4: +40 seconds"
echo "  • Attempt 5: +80 seconds"
echo "  • Attempt 6: +160 seconds → SUCCESS!"
echo ""

# Wait and show attempts
for i in {1..6}; do
    echo "⏳ Waiting for attempt #$i..."
    sleep 30
    
    # Check logs for this attempt
    echo "📋 Recent logs:"
    gcloud run services logs read data-processor-worker \
      --region=$REGION \
      --limit=10 \
      --format="value(textPayload)" | grep -E "(Attempt|CRASH|Success)" | tail -5
    echo ""
done

echo "========================================"
echo "✅ After ~5 minutes, check Firestore:"
echo "========================================"
echo "URL: https://console.cloud.google.com/firestore/data?project=$PROJECT_ID"
echo "Path: tenants/crash_recovery_demo/processed_logs/retry_demo_001"
echo ""
echo "Document should have: retry_attempts: 6"
echo "========================================"