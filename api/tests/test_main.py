"""
Unit tests for API service
Run with: pytest tests/
"""

import pytest
from fastapi.testclient import TestClient
from unittest.mock import Mock, patch, MagicMock
import json
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from main import app, normalize_to_internal_format


@pytest.fixture
def client():
    """Create test client"""
    return TestClient(app)


@pytest.fixture
def mock_pubsub():
    """Mock Pub/Sub publisher"""
    with patch('main.publisher') as mock_publisher:
        mock_future = MagicMock()
        mock_future.result.return_value = "test-message-id"
        mock_publisher.publish.return_value = mock_future
        yield mock_publisher


class TestHealthEndpoints:
    """Test health check endpoints"""
    
    def test_root_endpoint(self, client):
        """Test root endpoint returns healthy status"""
        response = client.get("/")
        assert response.status_code == 200
        assert response.json()["status"] == "healthy"
    
    def test_health_endpoint(self, client):
        """Test /health endpoint"""
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data


class TestJSONIngestion:
    """Test JSON payload ingestion"""
    
    def test_valid_json_ingestion(self, client, mock_pubsub):
        """Test successful JSON ingestion"""
        payload = {
            "tenant_id": "test_tenant",
            "log_id": "test_log_123",
            "text": "Test log message"
        }
        
        response = client.post(
            "/ingest",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 202
        data = response.json()
        assert data["status"] == "accepted"
        assert data["tenant_id"] == "test_tenant"
        assert data["log_id"] == "test_log_123"
        assert "message_id" in data
        
        # Verify Pub/Sub was called
        mock_pubsub.publish.assert_called_once()
    
    def test_json_without_tenant_id(self, client, mock_pubsub):
        """Test JSON without tenant_id returns 400"""
        payload = {
            "log_id": "test_log_123",
            "text": "Test log message"
        }
        
        response = client.post(
            "/ingest",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 400
        assert "tenant_id required" in response.json()["detail"]
    
    def test_json_auto_generates_log_id(self, client, mock_pubsub):
        """Test that log_id is auto-generated if not provided"""
        payload = {
            "tenant_id": "test_tenant",
            "text": "Test log message"
        }
        
        response = client.post(
            "/ingest",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 202
        data = response.json()
        assert "log_id" in data
        assert len(data["log_id"]) > 0
    
    def test_invalid_json(self, client):
        """Test invalid JSON returns 400"""
        response = client.post(
            "/ingest",
            data="invalid json {{{",
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 400


class TestTextIngestion:
    """Test plain text payload ingestion"""
    
    def test_valid_text_ingestion(self, client, mock_pubsub):
        """Test successful text ingestion"""
        text_data = "This is a test log message"
        
        response = client.post(
            "/ingest",
            data=text_data,
            headers={
                "Content-Type": "text/plain",
                "X-Tenant-ID": "test_tenant"
            }
        )
        
        assert response.status_code == 202
        data = response.json()
        assert data["status"] == "accepted"
        assert data["tenant_id"] == "test_tenant"
        assert "log_id" in data
        
        # Verify Pub/Sub was called
        mock_pubsub.publish.assert_called_once()
    
    def test_text_without_tenant_header(self, client, mock_pubsub):
        """Test text without X-Tenant-ID header returns 400"""
        text_data = "This is a test log message"
        
        response = client.post(
            "/ingest",
            data=text_data,
            headers={"Content-Type": "text/plain"}
        )
        
        assert response.status_code == 400
        assert "X-Tenant-ID header required" in response.json()["detail"]


class TestContentTypeHandling:
    """Test content type validation"""
    
    def test_unsupported_content_type(self, client):
        """Test unsupported content type returns 415"""
        response = client.post(
            "/ingest",
            data="test",
            headers={"Content-Type": "application/xml"}
        )
        
        assert response.status_code == 415
        assert "Unsupported content type" in response.json()["detail"]


class TestHelperFunctions:
    """Test helper functions"""
    
    def test_normalize_json_with_text_field(self):
        """Test normalization of JSON with text field"""
        data = {"text": "Test message", "other": "field"}
        result = normalize_to_internal_format(data)
        assert result == "Test message"
    
    def test_normalize_json_without_text_field(self):
        """Test normalization of JSON without text field"""
        data = {"field1": "value1", "field2": "value2"}
        result = normalize_to_internal_format(data)
        assert isinstance(result, str)
        assert "field1" in result


if __name__ == "__main__":
    pytest.main([__file__, "-v"])