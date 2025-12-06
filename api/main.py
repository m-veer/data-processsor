"""
FastAPI Ingestion Gateway
Handles JSON and TXT payloads, publishes to Pub/Sub
"""

from fastapi import FastAPI, Request, HTTPException, Header
from fastapi.responses import JSONResponse
from google.cloud import pubsub_v1
from typing import Optional
import json
import os
import logging
from datetime import datetime
import uuid

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Data Processor API")

# GCP Configuration
PROJECT_ID = os.getenv("GCP_PROJECT_ID")
TOPIC_ID = os.getenv("PUBSUB_TOPIC_ID", "data-ingestion")

# Initialize Pub/Sub Publisher
# publisher = pubsub_v1.PublisherClient()
try:
    publisher = pubsub_v1.PublisherClient()
    logger.info("✓ Pub/Sub client initialized successfully")
except Exception as e:
    logger.error(f"Failed to initialize Pub/Sub client: {e}")
    logger.error("Ensure GCP credentials are properly configured")
    raise

topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)


def normalize_to_internal_format(data: dict) -> str:
    """
    Normalize any input to flat text format
    """
    if "text" in data:
        return data["text"]
    return str(data)


def publish_to_pubsub(tenant_id: str, log_id: str, text: str, source: str):
    """
    Publish normalized message to Pub/Sub
    """
    message_data = {
        "tenant_id": tenant_id,
        "log_id": log_id,
        "text": text,
        "source": source,
        "ingested_at": datetime.utcnow().isoformat(),
    }

    # Serialize to JSON bytes
    message_bytes = json.dumps(message_data).encode("utf-8")

    # Publish with tenant_id as attribute for filtering
    future = publisher.publish(
        topic_path, message_bytes, tenant_id=tenant_id, source=source
    )

    # Wait for publish to complete (with timeout)
    try:
        message_id = future.result(timeout=5)
        logger.info(f"Published message {message_id} for tenant {tenant_id}")
        return message_id
    except Exception as e:
        logger.error(f"Failed to publish message: {e}")
        raise


@app.get("/")
async def root():
    """Health check endpoint"""
    return {"status": "healthy", "service": "data-processor-api", "version": "1.0.0"}


@app.get("/health")
async def health():
    """Detailed health check"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "pubsub_topic": topic_path,
    }


@app.post("/ingest")
async def ingest(
    request: Request,
    content_type: Optional[str] = Header(None),
    x_tenant_id: Optional[str] = Header(None, alias="X-Tenant-ID"),
):
    """
    Unified ingestion endpoint
    Handles both JSON and TXT payloads
    Returns immediately (async/non-blocking)
    """
    try:
        # Determine content type
        content_type_header = content_type or request.headers.get("content-type", "")

        tenant_id = None
        log_id = str(uuid.uuid4())
        text = None
        source = None

        # Scenario 1: JSON payload
        if "application/json" in content_type_header.lower():
            try:
                body = await request.json()

                # Extract tenant_id from payload
                tenant_id = body.get("tenant_id")
                if not tenant_id:
                    raise HTTPException(
                        status_code=400, detail="tenant_id required in JSON payload"
                    )

                # Extract or generate log_id
                log_id = body.get("log_id", str(uuid.uuid4()))

                # Normalize to internal format
                text = normalize_to_internal_format(body)
                source = "json_upload"

            except json.JSONDecodeError:
                raise HTTPException(status_code=400, detail="Invalid JSON payload")

        # Scenario 2: Plain text payload
        elif "text/plain" in content_type_header.lower():
            # Extract tenant_id from header
            tenant_id = x_tenant_id
            if not tenant_id:
                raise HTTPException(
                    status_code=400, detail="X-Tenant-ID header required for text/plain"
                )

            # Read raw text
            body_bytes = await request.body()
            text = body_bytes.decode("utf-8")
            source = "text_upload"

        else:
            raise HTTPException(
                status_code=415,
                detail="Unsupported content type. Use application/json or text/plain",
            )

        # Validate required fields
        if not tenant_id or not text:
            raise HTTPException(status_code=400, detail="Missing required fields")

        # Publish to Pub/Sub (non-blocking from API perspective)
        try:
            message_id = publish_to_pubsub(tenant_id, log_id, text, source)
        except Exception as e:
            logger.error(f"Pub/Sub publish failed: {e}")
            raise HTTPException(
                status_code=500, detail="Failed to queue message for processing"
            )

        # Return immediately (202 Accepted)
        return JSONResponse(
            status_code=202,
            content={
                "status": "accepted",
                "tenant_id": tenant_id,
                "log_id": log_id,
                "message_id": message_id,
                "message": "Data queued for processing",
            },
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in /ingest: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error: {str(e)}")


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler for unexpected errors"""
    logger.error(f"Unhandled exception: {exc}")
    return JSONResponse(status_code=500, content={"detail": "Internal server error"})


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
