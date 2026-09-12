from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Optional, List, Dict, Any


@dataclass
class EvidenceUploadResult:
    public_id: str
    secure_url: str
    resource_type: str = "image"
    format: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    bytes: Optional[int] = None
    version: Optional[str] = None
    etag: Optional[str] = None
    thumbnail_url: Optional[str] = None


class ICloudStorageService(ABC):
    """
    Storage abstraction for evidence images.
    Decouples evidence generation & compliance checks from raw vendor SDK calls.
    """

    @abstractmethod
    async def upload_evidence_image(
        self,
        file_bytes: bytes,
        public_id: str,
        folder: Optional[str] = None,
        tags: Optional[List[str]] = None,
        context: Optional[Dict[str, str]] = None,
    ) -> EvidenceUploadResult:
        """
        Uploads an evidence image and returns upload metadata.
        """
        ...

    @abstractmethod
    async def delete_evidence_image(self, public_id: str) -> bool:
        """
        Deletes an evidence image by public_id if explicitly authorized.
        """
        ...

    @abstractmethod
    def get_evidence_url(
        self,
        public_id: str,
        transformation: Optional[str] = None,
    ) -> Optional[str]:
        """
        Generates or resolves the secure HTTPS URL for a public_id.
        """
        ...

    @abstractmethod
    async def check_evidence_exists(self, public_id: str) -> bool:
        """
        Checks whether an asset exists in cloud storage.
        """
        ...
