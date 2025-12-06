"""
PyTest configuration for worker tests
Mocks GCP dependencies BEFORE any imports
"""

import sys
from unittest.mock import MagicMock

# Create mock modules BEFORE pytest collects tests
mock_firestore = MagicMock()
mock_pubsub = MagicMock()

# Mock the google.cloud.firestore module
sys.modules["google.cloud.firestore"] = mock_firestore
sys.modules["google.cloud.pubsub_v1"] = mock_pubsub

# Create mock clients
mock_firestore.Client = MagicMock
mock_pubsub.SubscriberClient = MagicMock
mock_pubsub.types = MagicMock()
mock_pubsub.types.FlowControl = MagicMock

# Mock subscriber message type
mock_message_class = MagicMock()
mock_pubsub.subscriber = MagicMock()
mock_pubsub.subscriber.message = MagicMock()
mock_pubsub.subscriber.message.Message = mock_message_class
