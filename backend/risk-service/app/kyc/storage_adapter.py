"""
Storage Adapter Interface & Implementations for e-KYC Blobs.
"""

from abc import ABC, abstractmethod
import os
import logging
from typing import Dict, Optional

logger = logging.getLogger(__name__)


class BlobStorageAdapter(ABC):
    """Abstract interface isolating object storage from computer vision pipeline."""

    @abstractmethod
    def fetch_image_bytes(self, blob_path: str) -> bytes:
        """Retrieves raw image bytes from storage vault."""
        pass


class AzuriteBlobStorageAdapter(BlobStorageAdapter):
    """Azure Blob Storage / Azurite implementation."""

    def __init__(self, connection_string: Optional[str] = None, container_name: str = "kyc-vault"):
        self.container_name = container_name
        self.connection_string = connection_string or os.getenv(
            "AZURE_STORAGE_CONNECTION_STRING",
            "DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;"
            "AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;"
            "BlobEndpoint=http://azurite-storage:10000/devstoreaccount1;",
        )
        self._blob_service_client = None

    def _get_client(self):
        if self._blob_service_client is None:
            try:
                from azure.storage.blob import BlobServiceClient
                self._blob_service_client = BlobServiceClient.from_connection_string(self.connection_string)
            except Exception as e:
                logger.error(f"Failed to initialize BlobServiceClient: {e}")
                raise
        return self._blob_service_client

    def fetch_image_bytes(self, blob_path: str) -> bytes:
        client = self._get_client()
        container_client = client.get_container_client(self.container_name)
        blob_client = container_client.get_blob_client(blob_path)
        return blob_client.download_blob().readall()


class MockBlobStorageAdapter(BlobStorageAdapter):
    """Mock storage adapter for deterministic offline unit testing."""

    def __init__(self, initial_data: Optional[Dict[str, bytes]] = None):
        self._store: Dict[str, bytes] = initial_data or {}

    def set_blob(self, blob_path: str, data: bytes) -> None:
        self._store[blob_path] = data

    def fetch_image_bytes(self, blob_path: str) -> bytes:
        if blob_path in self._store:
            return self._store[blob_path]
        # Return synthetic recognizable byte buffer if not set
        return f"SYNTHETIC_IMAGE_BYTES_FOR_{blob_path}".encode("utf-8")
