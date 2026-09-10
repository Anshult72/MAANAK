import os
import hashlib
import uuid
import aiofiles
from abc import ABC, abstractmethod
from PIL import Image
from typing import Tuple, Optional
from app.core.config import settings
from app.core.logging import logger


class IFileStorage(ABC):
    """Abstract storage interface.

    Implementations:
      - StorageManager  (local filesystem — current prototype)
      - Future: S3Storage, MinIOStorage, etc.

    ⚠️  FILE PERSISTENCE WARNING:
    Railway (like Render) uses an ephemeral filesystem by default.
    Files written to local disk will be lost on redeploy/restart unless
    a persistent Railway volume is mounted at STORAGE_ROOT.

    For the current prototype, uploaded images are also persisted as
    base64 inside the database (quality_details JSON) so the OCR
    pipeline can restore them automatically. Reports and evidence
    crops are regenerable and do not require permanent storage.
    """

    @abstractmethod
    async def save_inspection_image(
        self, inspection_id: str, file_bytes: bytes, filename: str
    ) -> Tuple[str, str, int, int, str]:
        """Save original image + thumbnail. Returns (orig_path, thumb_path, w, h, sha256)."""
        ...

    @abstractmethod
    async def save_evidence_crop(
        self, original_path: str, bbox: dict, finding_id: str
    ) -> Optional[str]:
        """Crop bbox from original image. Returns crop path or None."""
        ...

    @abstractmethod
    async def save_report_pdf(
        self, inspection_id: str, file_bytes: bytes, version: int
    ) -> Tuple[str, str]:
        """Save PDF bytes. Returns (file_path, sha256)."""
        ...

    @abstractmethod
    async def save_report_docx(
        self, inspection_id: str, file_bytes: bytes, version: int
    ) -> Tuple[str, str]:
        """Save DOCX bytes. Returns (file_path, sha256)."""
        ...


class StorageManager(IFileStorage):
    """Local filesystem storage implementation (prototype).

    Suitable for development and Railway deployments with a mounted volume.
    """

    def __init__(self, root_dir: str = settings.STORAGE_ROOT):
        self.root_dir = root_dir
        self.inspections_dir = os.path.join(root_dir, "inspections")
        self.evidence_dir = os.path.join(root_dir, "evidence")
        self.reports_dir = os.path.join(root_dir, "reports")
        self.listing_dir = os.path.join(root_dir, "listing_snapshots")
        self.labels_dir = os.path.join(root_dir, "label_versions")
        
        self._ensure_dirs()

    def _ensure_dirs(self):
        for d in [self.root_dir, self.inspections_dir, self.evidence_dir, self.reports_dir, self.listing_dir, self.labels_dir]:
            os.makedirs(d, exist_ok=True)

    async def save_inspection_image(self, inspection_id: str, file_bytes: bytes, filename: str) -> Tuple[str, str, int, int, str]:
        """
        Saves original inspection image and creates a thumbnail.
        Returns: (original_rel_path, thumb_rel_path, width, height, sha256_hash)
        """
        sha256 = hashlib.sha256(file_bytes).hexdigest()
        ext = os.path.splitext(filename)[1].lower() or ".jpg"
        unique_name = f"{uuid.uuid4()}{ext}"
        
        inspection_folder = os.path.join(self.inspections_dir, inspection_id)
        os.makedirs(inspection_folder, exist_ok=True)
        
        orig_path = os.path.join(inspection_folder, unique_name)
        async with aiofiles.open(orig_path, "wb") as f:
            await f.write(file_bytes)
            
        # Get dimensions & generate thumbnail
        try:
            with Image.open(orig_path) as img:
                width, height = img.size
                
                thumb_name = f"thumb_{unique_name}"
                thumb_path = os.path.join(inspection_folder, thumb_name)
                
                img_copy = img.copy()
                img_copy.thumbnail((300, 300))
                img_copy.save(thumb_path)
        except Exception as e:
            logger.warning(f"Error creating thumbnail for {orig_path}: {e}")
            width, height = 800, 600
            thumb_path = orig_path

        return orig_path, thumb_path, width, height, sha256

    async def save_evidence_crop(self, original_path: str, bbox: dict, finding_id: str) -> Optional[str]:
        """
        Crops bbox from original image and saves in evidence directory.
        bbox: {x, y, width, height}
        """
        try:
            if not os.path.exists(original_path):
                return None
            
            with Image.open(original_path) as img:
                img_w, img_h = img.size
                x = max(0, int(bbox.get("x", 0)))
                y = max(0, int(bbox.get("y", 0)))
                w = int(bbox.get("width", 100))
                h = int(bbox.get("height", 50))
                
                x2 = min(img_w, x + w)
                y2 = min(img_h, y + h)
                
                crop_img = img.crop((x, y, x2, y2))
                crop_name = f"evidence_{finding_id}_{uuid.uuid4().hex[:8]}.jpg"
                crop_path = os.path.join(self.evidence_dir, crop_name)
                crop_img.save(crop_path, "JPEG")
                return crop_path
        except Exception as e:
            logger.warning(f"Failed to generate evidence crop: {e}")
            return None

    async def save_report_pdf(self, inspection_id: str, file_bytes: bytes, version: int) -> Tuple[str, str]:
        """
        Saves uploaded/archived PDF bytes and returns (file_path, sha256).
        """
        sha256 = hashlib.sha256(file_bytes).hexdigest()
        filename = f"MAANAK_REPORT_{inspection_id}_v{version}_{sha256[:8]}.pdf"
        file_path = os.path.join(self.reports_dir, filename)
        
        async with aiofiles.open(file_path, "wb") as f:
            await f.write(file_bytes)
            
        return file_path, sha256

    async def save_report_docx(self, inspection_id: str, file_bytes: bytes, version: int) -> Tuple[str, str]:
        """
        Saves generated DOCX bytes and returns (file_path, sha256).
        """
        sha256 = hashlib.sha256(file_bytes).hexdigest()
        filename = f"MAANAK_REPORT_{inspection_id}_v{version}_{sha256[:8]}.docx"
        file_path = os.path.join(self.reports_dir, filename)
        
        async with aiofiles.open(file_path, "wb") as f:
            await f.write(file_bytes)
            
        return file_path, sha256

storage_manager = StorageManager()
