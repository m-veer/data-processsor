"""
Run API locally with mocked Pub/Sub
No GCP credentials needed!
"""

import uvicorn
from unittest.mock import patch, MagicMock

# Mock GCP Pub/Sub BEFORE importing main
mock_publisher = MagicMock()
mock_future = MagicMock()
mock_future.result.return_value = "local-mock-message-id"
mock_publisher.publish.return_value = mock_future
mock_publisher.topic_path.return_value = "projects/local/topics/data-ingestion"

with patch('google.cloud.pubsub_v1.PublisherClient', return_value=mock_publisher):
    from main import app

print("=" * 60)
print("🚀 Starting LOCAL API Server (Mocked Pub/Sub)")
print("=" * 60)
print("API will be available at: http://localhost:8080")
print("Health check: http://localhost:8080/health")
print("Press CTRL+C to stop")
print("=" * 60)

if __name__ == "__main__":
    uvicorn.run(
        "run_local:app",
        host="0.0.0.0",
        port=8080,
        reload=True,
        log_level="info"
    )