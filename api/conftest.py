"""
PyTest configuration and shared fixtures
Mocks GCP dependencies for all tests
"""

import os
import sys
from unittest.mock import MagicMock, patch

import pytest

# Ensure parent directory is in path
sys.path.insert(0, os.path.dirname(__file__))


@pytest.fixture(scope="session", autouse=True)
def mock_gcp_publisher():
    """Mock Pub/Sub Publisher for all tests"""
    with patch("google.cloud.pubsub_v1.PublisherClient") as mock_class:
        mock_publisher = MagicMock()
        mock_publisher.topic_path.return_value = "projects/test/topics/test-topic"

        mock_future = MagicMock()
        mock_future.result.return_value = "mock-message-id"
        mock_publisher.publish.return_value = mock_future

        mock_class.return_value = mock_publisher
        yield mock_publisher
