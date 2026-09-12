import asyncio
import io
import os
from typing import Optional, List, Dict, Any
from PIL import Image
import cloudinary
import cloudinary.uploader
import cloudinary.api
import cloudinary.utils

from app.core.config import settings
from app.core.logging import logger
from app.services.storage.cloud_storage_interface import (
    ICloudStorageService,
    EvidenceUploadResult
)


class CloudinaryStorageService(ICloudStorageService):
    """
    Official Cloudinary SDK implementation for persistent inspection evidence images.
    Uploads preprocessed evidence crops, annotated overlays, and compliance findings.
    """

    def __init__(self):
        self.cloud_name = settings.CLOUDINARY_CLOUD_NAME
        self.api_key = settings.CLOUDINARY_API_KEY
        self.api_secret = settings.CLOUDINARY_API_SECRET
        self.folder = settings.CLOUDINARY_FOLDER or "lm_trace/evidence"
        self.secure = settings.CLOUDINARY_SECURE
        self.enabled = settings.CLOUDINARY_ENABLED and settings.cloudinary_configured

        if self.enabled:
            cloudinary.config(
                cloud_name=self.cloud_name,
                api_key=self.api_key,
                api_secret=self.api_secret,
                secure=self.secure,
            )
            logger.info("Cloudinary storage service configured for cloud: %s", self.cloud_name)
        else:
            logger.info("Cloudinary storage service is disabled or credentials not fully set.")

    def _validate_image_bytes(self, file_bytes: bytes) -> tuple[int, int, str]:
        """
        Validates image dimensions and MIME/format.
        Returns: (width, height, format_ext)
        """
        max_bytes = settings.MAX_EVIDENCE_IMAGE_SIZE_MB * 1024 * 1024
        if len(file_bytes) > max_bytes:
            raise ValueError(f"Evidence image exceeds max size limit of {settings.MAX_EVIDENCE_IMAGE_SIZE_MB}MB")

        try:
            with Image.open(io.BytesIO(file_bytes)) as img:
                img.verify()
            with Image.open(io.BytesIO(file_bytes)) as img:
                width, height = img.size
                fmt = (img.format or "JPEG").lower()
                return width, height, fmt
        except Exception as e:
            raise ValueError(f"Invalid image content: {e}") from e

    async def upload_evidence_image(
        self,
        file_bytes: bytes,
        public_id: str,
        folder: Optional[str] = None,
        tags: Optional[List[str]] = None,
        context: Optional[Dict[str, str]] = None,
    ) -> EvidenceUploadResult:
        if not self.enabled:
            raise RuntimeError("Cloudinary is disabled or not configured.")

        width, height, img_fmt = self._validate_image_bytes(file_bytes)
        target_folder = folder or self.folder

        upload_options: Dict[str, Any] = {
            "public_id": public_id,
            "folder": target_folder,
            "resource_type": "image",
            "overwrite": False,
            "unique_filename": False,
            "tags": tags or ["evidence", "lm_trace"],
        }

        if context:
            # Flatten context for Cloudinary metadata
            upload_options["context"] = context

        logger.info("Initiating Cloudinary upload for public_id: %s (size: %d bytes)", public_id, len(file_bytes))

        # Run synchronous Cloudinary SDK call in threadpool
        def _do_upload():
            return cloudinary.uploader.upload(
                io.BytesIO(file_bytes),
                **upload_options
            )

        try:
            res = await asyncio.to_thread(_do_upload)
            sec_url = res.get("secure_url") or res.get("url") or ""
            actual_public_id = res.get("public_id") or f"{target_folder}/{public_id}"

            # Derive thumbnail URL via Cloudinary transform
            thumb_url = None
            try:
                thumb_url, _ = cloudinary.utils.cloudinary_url(
                    actual_public_id,
                    transformation=[
                        {"width": 300, "height": 300, "crop": "thumb", "gravity": "auto"}
                    ],
                    secure=self.secure,
                )
            except Exception:
                pass

            result = EvidenceUploadResult(
                public_id=actual_public_id,
                secure_url=sec_url,
                resource_type=res.get("resource_type", "image"),
                format=res.get("format", img_fmt),
                width=res.get("width", width),
                height=res.get("height", height),
                bytes=res.get("bytes", len(file_bytes)),
                version=str(res.get("version", "")),
                etag=res.get("etag"),
                thumbnail_url=thumb_url,
            )
            logger.info("Cloudinary upload successful for %s: %s", actual_public_id, sec_url)
            return result
        except Exception as e:
            logger.error("Cloudinary upload failed for public_id %s: %s", public_id, e)
            raise RuntimeError(f"Cloudinary upload failed: {e}") from e

    async def delete_evidence_image(self, public_id: str) -> bool:
        if not self.enabled:
            return False

        def _do_destroy():
            return cloudinary.uploader.destroy(public_id, resource_type="image")

        try:
            res = await asyncio.to_thread(_do_destroy)
            return res.get("result") in ["ok", "not found"]
        except Exception as e:
            logger.error("Failed to delete Cloudinary asset %s: %s", public_id, e)
            return False

    def get_evidence_url(
        self,
        public_id: str,
        transformation: Optional[str] = None,
    ) -> Optional[str]:
        if not public_id:
            return None
        try:
            options: Dict[str, Any] = {"secure": self.secure}
            if transformation:
                options["raw_transformation"] = transformation
            url, _ = cloudinary.utils.cloudinary_url(public_id, **options)
            return url
        except Exception as e:
            logger.warning("Failed to resolve Cloudinary URL for %s: %s", public_id, e)
            return None

    async def check_evidence_exists(self, public_id: str) -> bool:
        if not self.enabled:
            return False

        def _do_check():
            try:
                res = cloudinary.api.resource(public_id, resource_type="image")
                return bool(res and res.get("public_id"))
            except Exception:
                return False

        return await asyncio.to_thread(_do_check)


cloudinary_storage_service = CloudinaryStorageService()
