"""
Worker Service
Processes messages from Pub/Sub, simulates heavy processing, stores in Firestore
Includes HTTP health check endpoint for Cloud Run
NOW WITH: Crash simulation that succeeds after 5 attempts
"""

from google.cloud import pubsub_v1, firestore
from concurrent.futures import TimeoutError
import json
import os
import logging
import time
import re
from datetime import datetime
from threading import Thread
from http.server import HTTPServer, BaseHTTPRequestHandler

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# GCP Configuration
PROJECT_ID = os.getenv("GCP_PROJECT_ID")
SUBSCRIPTION_ID = os.getenv("PUBSUB_SUBSCRIPTION_ID", "data-ingestion-sub")

# Initialize Firestore
db = firestore.Client(project=PROJECT_ID)

# Initialize Pub/Sub Subscriber
subscriber = pubsub_v1.SubscriberClient()
subscription_path = subscriber.subscription_path(PROJECT_ID, SUBSCRIPTION_ID)


class HealthCheckHandler(BaseHTTPRequestHandler):
    """Simple HTTP handler for health checks"""

    def do_GET(self):
        """Handle GET requests for health checks"""
        if self.path == "/health" or self.path == "/":
            self.send_response(200)
            self.send_header("Content-type", "application/json")
            self.end_headers()
            response = json.dumps(
                {
                    "status": "healthy",
                    "service": "data-processor-worker",
                    "subscription": SUBSCRIPTION_ID,
                    "retry_counter_size": len(retry_counter),
                }
            )
            self.wfile.write(response.encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        """Suppress default logging"""
        pass


def start_health_check_server():
    """Start HTTP server for Cloud Run health checks"""
    port = int(os.getenv("PORT", 8080))
    server = HTTPServer(("0.0.0.0", port), HealthCheckHandler)
    logger.info(f"Health check server started on port {port}")
    server.serve_forever()


def redact_pii(text: str) -> str:
    """
    Simple PII redaction - redacts phone numbers
    Example: 555-0199 -> [REDACTED]
    """
    # Redact phone numbers (simple pattern)
    redacted = re.sub(r"\b\d{3}-\d{4}\b", "[REDACTED]", text)
    redacted = re.sub(r"\b\d{3}-\d{3}-\d{4}\b", "[REDACTED]", redacted)
    return redacted


def simulate_heavy_processing(text: str):
    """
    Simulate CPU-bound processing
    Sleep 0.05s per character
    """
    char_count = len(text)
    sleep_time = char_count * 0.05

    logger.info(f"Processing {char_count} characters, sleeping for {sleep_time}s")
    time.sleep(sleep_time)


def store_in_firestore(tenant_id: str, log_id: str, data: dict):
    """
    Store processed data in Firestore with strict multi-tenant isolation
    Structure: tenants/{tenant_id}/processed_logs/{log_id}
    """
    try:
        # Multi-tenant path structure
        doc_ref = (
            db.collection("tenants")
            .document(tenant_id)
            .collection("processed_logs")
            .document(log_id)
        )

        # Store with timestamp
        doc_ref.set(data)

        logger.info(f"Stored log {log_id} for tenant {tenant_id}")
        return True

    except Exception as e:
        logger.error(f"Failed to store in Firestore: {e}")
        raise


def process_message(message: pubsub_v1.subscriber.message.Message):
    """
    Process a single Pub/Sub message
    """
    try:
        # Parse message data
        message_data = json.loads(message.data.decode("utf-8"))

        delivery_attempt = message.delivery_attempt or 1

        logger.info(f"📬 Delivery attempt #{delivery_attempt}")

        tenant_id = message_data.get("tenant_id")
        log_id = message_data.get("log_id")
        text = message_data.get("text")
        source = message_data.get("source")
        ingested_at = message_data.get("ingested_at")

        logger.info(f"Processing message for tenant={tenant_id}, log_id={log_id}")

        # 🧪 CRASH TEST: Fail first 5 attempts, then succeed
        if "crash_test" in text.lower():
            if delivery_attempt <= 5:
                logger.error(f"🔥 CRASH (Attempt {delivery_attempt}/5)")
                raise Exception(f"Simulated crash - Attempt {delivery_attempt}")
            else:
                logger.info(f"✅ PASSED after {delivery_attempt} attempts")

        # Normal processing continues...
        simulate_heavy_processing(text)

        # Redact PII
        modified_data = redact_pii(text)

        # Prepare document for storage
        document = {
            "source": source,
            "original_text": text,
            "modified_data": modified_data,
            "ingested_at": ingested_at,
            "processed_at": datetime.utcnow().isoformat(),
            "character_count": len(text),
            "processing_time_seconds": len(text) * 0.05,
            # "retry_attempts": retry_counter.get(f"{tenant_id}:{log_id}", 0)  # Track retries
            # "retry_attempts": retry_count  # Track retries
            "delivery_attempt(s)": delivery_attempt,  # Use Pub/Sub's counter
        }

        # Store in Firestore with multi-tenant isolation
        store_in_firestore(tenant_id, log_id, document)

        # Acknowledge message (prevents reprocessing)
        message.ack()
        logger.info(f"✅ Successfully processed and acked message {message.message_id}")

    except Exception as e:
        logger.error(f"❌ Error processing message: {e}")
        # NACK the message to retry later (handles crash scenarios)
        message.nack()
        logger.info(f"🔄 Message {message.message_id} nacked for retry")


def callback(message: pubsub_v1.subscriber.message.Message):
    """
    Callback for each message received
    """
    process_message(message)


def main():
    """
    Main worker loop - subscribes to Pub/Sub and processes messages
    """
    logger.info(f"Worker starting, subscribing to {subscription_path}")

    # Start health check server in background thread
    health_thread = Thread(target=start_health_check_server, daemon=True)
    health_thread.start()
    logger.info("Health check endpoint available at /health")

    # Configure flow control for high throughput
    flow_control = pubsub_v1.types.FlowControl(
        max_messages=100,  # Process up to 100 messages concurrently
        max_bytes=100 * 1024 * 1024,  # 100 MB
    )

    # Start streaming pull
    streaming_pull_future = subscriber.subscribe(
        subscription_path, callback=callback, flow_control=flow_control
    )

    logger.info(f"Listening for messages on {subscription_path}")

    # Keep the worker running
    try:
        # Block indefinitely
        streaming_pull_future.result()
    except TimeoutError:
        streaming_pull_future.cancel()
        streaming_pull_future.result()
    except KeyboardInterrupt:
        streaming_pull_future.cancel()
        logger.info("Worker stopped by user")
    except Exception as e:
        logger.error(f"Worker error: {e}")
        streaming_pull_future.cancel()
        raise


if __name__ == "__main__":
    main()
