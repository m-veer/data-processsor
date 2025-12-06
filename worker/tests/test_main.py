"""
Unit tests for Worker service
Run with: pytest tests/
"""

import pytest
from unittest.mock import Mock, patch, MagicMock
import json
import sys
import os
import time

# Add parent directory to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))


# Mock GCP services before importing
@pytest.fixture(scope="session", autouse=True)
def mock_gcp_services():
    """Mock all GCP services for testing"""
    with patch("google.cloud.firestore.Client"), patch("google.cloud.pubsub_v1.SubscriberClient"):
        yield


from main import redact_pii, simulate_heavy_processing


class TestPIIRedaction:
    """Test PII redaction functionality"""

    def test_redact_phone_number_format1(self):
        """Test redaction of XXX-XXXX format"""
        text = "Call me at 555-0199"
        result = redact_pii(text)
        assert result == "Call me at [REDACTED]"

    def test_redact_phone_number_format2(self):
        """Test redaction of XXX-XXX-XXXX format"""
        text = "Contact: 555-123-4567"
        result = redact_pii(text)
        assert result == "Contact: [REDACTED]"

    def test_redact_multiple_phone_numbers(self):
        """Test redaction of multiple phone numbers"""
        text = "Call 555-0199 or 555-1234"
        result = redact_pii(text)
        assert "[REDACTED]" in result
        assert "555-0199" not in result
        assert "555-1234" not in result

    def test_no_pii_to_redact(self):
        """Test text with no PII"""
        text = "This is a normal message"
        result = redact_pii(text)
        assert result == text


class TestHeavyProcessing:
    """Test simulated heavy processing"""

    def test_processing_time_calculation(self):
        """Test that processing time is correct"""
        text = "a" * 20  # 20 characters (reduced from 100 for faster tests)
        expected_time = 20 * 0.05  # 1 second

        start_time = time.time()
        simulate_heavy_processing(text)
        end_time = time.time()

        actual_time = end_time - start_time

        # Allow 0.2 second tolerance
        assert abs(actual_time - expected_time) < 0.2

    def test_processing_empty_string(self):
        """Test processing with empty string"""
        start_time = time.time()
        simulate_heavy_processing("")
        end_time = time.time()

        # Should be nearly instant
        assert (end_time - start_time) < 0.1


class TestFirestoreStorage:
    """Test Firestore storage functionality"""

    @patch("main.db")
    def test_store_document_success(self, mock_db):
        """Test successful document storage"""
        from main import store_in_firestore
        
        mock_collection = MagicMock()
        mock_db.collection.return_value = mock_collection

        data = {"source": "json_upload", "original_text": "test", "modified_data": "test"}

        result = store_in_firestore("test_tenant", "log_123", data)

        assert result is True
        mock_db.collection.assert_called_with("tenants")

    @patch("main.db")
    def test_store_with_correct_path(self, mock_db):
        """Test that document is stored in correct path"""
        from main import store_in_firestore
        
        mock_collection = MagicMock()
        mock_document = MagicMock()
        mock_sub_collection = MagicMock()

        mock_db.collection.return_value = mock_collection
        mock_collection.document.return_value = mock_document
        mock_document.collection.return_value = mock_sub_collection

        data = {"test": "data"}
        store_in_firestore("acme", "log_123", data)

        # Verify path: tenants/acme/processed_logs/log_123
        mock_db.collection.assert_called_with("tenants")
        mock_collection.document.assert_called_with("acme")
        mock_document.collection.assert_called_with("processed_logs")


class TestMessageProcessing:
    """Test message processing workflow"""

    @patch("main.store_in_firestore")
    @patch("main.simulate_heavy_processing")
    @patch("main.redact_pii")
    def test_successful_message_processing(self, mock_redact, mock_process, mock_store):
        """Test successful end-to-end message processing"""
        from main import process_message
        
        mock_redact.return_value = "User [REDACTED] accessed the system"
        mock_store.return_value = True

        # Create mock message
        mock_message = MagicMock()
        message_data = {
            "tenant_id": "test_tenant",
            "log_id": "test_123",
            "text": "User 555-0199 accessed the system",
            "source": "json_upload",
            "ingested_at": "2024-01-01T00:00:00Z",
        }
        mock_message.data = json.dumps(message_data).encode("utf-8")
        mock_message.message_id = "msg_123"
        mock_message.delivery_attempt = 1

        # Process message
        process_message(mock_message)

        # Verify processing steps
        mock_process.assert_called_once()
        mock_redact.assert_called_once()
        mock_store.assert_called_once()
        mock_message.ack.assert_called_once()

    @patch("main.store_in_firestore")
    @patch("main.simulate_heavy_processing")
    def test_message_processing_failure(self, mock_process, mock_store):
        """Test message processing with failure"""
        from main import process_message
        
        mock_store.side_effect = Exception("Storage failed")

        # Create mock message
        mock_message = MagicMock()
        message_data = {
            "tenant_id": "test_tenant",
            "log_id": "test_123",
            "text": "Test message",
            "source": "json_upload",
            "ingested_at": "2024-01-01T00:00:00Z",
        }
        mock_message.data = json.dumps(message_data).encode("utf-8")
        mock_message.delivery_attempt = 1

        # Process message (should not raise, but should NACK)
        process_message(mock_message)

        # Verify message was NACKed
        mock_message.nack.assert_called_once()
        mock_message.ack.assert_not_called()


if __name__ == "__main__":
    pytest.main([__file__, "-v"])