import hashlib
import io
from typing import Optional, List, Dict, Any
from PIL import Image

from app.services.storage.cloud_storage_interface import (
    ICloudStorageService,
    EvidenceUploadResult
)


class MockCloudStorageService(ICloudStorageService):
    """
    In-memory mock cloud storage service for unit tests and local development.
    Avoids requiring real external Cloudinary API calls or credentials.
    """

    def __init__(self, cloud_name: str = "demo-cloud", folder: str = "lm_trace/evidence"):
        self.cloud_name = cloud_name
        self.folder = folder
        self._stored_assets: Dict[str, Dict[str, Any]] = {}

    async def upload_evidence_image(
        self,
        file_bytes: bytes,
        public_id: str,
        folder: Optional[str] = None,
        tags: Optional[List[str]] = None,
        context: Optional[Dict[str, str]] = None,
    ) -> EvidenceUploadResult:
        # Validate format
        try:
            with Image.open(io.BytesIO(file_bytes)) as img:
                width, height = img.size
                fmt = (img.format or "JPEG").lower()
        except Exception:
            width, height, fmt = 800, 600, "jpeg"

        target_folder = folder or self.folder
        full_public_id = f"{target_folder}/{public_id}" if not public_id.startswith(target_folder) else public_id
        sha256 = hashlib.sha256(file_bytes).hexdigest()

        sec_url = f"https://res.cloudinary.com/{self.cloud_name}/image/upload/v1/mock/{full_public_id}.{fmt}"
        thumb_url = f"https://res.cloudinary.com/{self.cloud_name}/image/upload/c_thumb,w_300,h_300/mock/{full_public_id}.{fmt}"

        result = EvidenceUploadResult(
            public_id=full_public_id,
            secure_url=sec_url,
            resource_type="image",
            format=fmt,
            width=width,
            height=height,
            bytes=len(file_bytes),
            version="1",
            etag=sha256[:16],
            thumbnail_url=thumb_url,
        )

        self._stored_assets[full_public_id] = {
            "result": result,
            "bytes": file_bytes,
            "tags": tags or [],
            "context": context or {},
        }

        return result

    async def delete_evidence_image(self, public_id: str) -> bool:
        if public_id in self._stored_assets:
            del self._stored_assets[public_id]
            return True
        return False

    def get_evidence_url(
        self,
        public_id: str,
        transformation: Optional[str] = None,
    ) -> Optional[str]:
        if not public_id:
            return None
        trans_prefix = f"{transformation}/" if transformation else ""
        return f"https://res.cloudinary.com/{self.cloud_name}/image/upload/{trans_prefix}mock/{public_id}.jpg"

    async def check_evidence_exists(self, public_id: str) -> bool:
        return public_id in self._stored_assets

    def clear(self):
        self._stored_assets.clear()
