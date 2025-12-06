"""
PyTest configuration for worker tests
Mocks GCP dependencies
"""

import pytest
from unittest.mock import MagicMock, patch
import sys
import os

sys.path.insert(0, os.path.dirname(__file__))


@pytest.fixture(scope="session", autouse=True)
def mock_gcp_services():
    """Mock Firestore and Pub/Sub for all tests"""
    with patch("google.cloud.firestore.Client") as mock_firestore, \
         patch("google.cloud.pubsub_v1.SubscriberClient") as mock_subscriber:
        
        # Mock Firestore client
        mock_db = MagicMock()
        mock_firestore.return_value = mock_db
        
        # Mock Subscriber client
        mock_sub = MagicMock()
        mock_subscriber.return_value = mock_sub
        
        yield {"firestore": mock_db, "subscriber": mock_sub}