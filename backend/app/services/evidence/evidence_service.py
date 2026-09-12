import hashlib
import io
import os
import uuid
from typing import List, Dict, Any, Optional
import cv2
import numpy as np
from PIL import Image

from app.core.config import settings
from app.core.logging import logger
from app.storage.file_storage import storage_manager
from app.services.storage.cloud_storage_interface import ICloudStorageService
from app.services.storage.cloudinary_service import cloudinary_storage_service


class EvidenceService:
    """
    Evidence Service for LM-TRACE.
    Generates preprocessed evidence artifacts (crops, annotated bounding box overlays,
    Rule 7 measurement crops, violation evidence) and archives them to Cloudinary
    with cryptographic SHA-256 integrity verification and Neon PostgreSQL persistence.
    """

    def __init__(self, storage_service: Optional[ICloudStorageService] = None):
        self._storage_service = storage_service or cloudinary_storage_service

    @property
    def storage(self) -> ICloudStorageService:
        return self._storage_service

    @storage.setter
    def storage(self, service: ICloudStorageService):
        self._storage_service = service

    @staticmethod
    def compute_sha256(data: bytes) -> str:
        """Calculates cryptographic SHA-256 digest of image bytes for legal integrity verification."""
        return hashlib.sha256(data).hexdigest()

    async def generate_and_store_crop(
        self,
        inspection_id: str,
        original_image_path: str,
        bbox: Dict[str, Any],
        evidence_type: str = "DECLARATION_CROP",
        finding_id: Optional[str] = None,
        image_id: Optional[str] = None,
        description: Optional[str] = None,
        created_by: Optional[str] = "SYSTEM_PIPELINE",
    ) -> Dict[str, Any]:
        """
        Crops a bounding box from an image, calculates SHA-256,
        and uploads the preprocessed crop to Cloudinary.
        """
        evidence_id = f"ev-{uuid.uuid4().hex[:10]}"
        if not os.path.exists(original_image_path):
            logger.warning("Original image not found for crop: %s", original_image_path)
            return {
                "id": evidence_id,
                "inspection_id": inspection_id,
                "image_id": image_id,
                "finding_id": finding_id,
                "evidence_type": evidence_type,
                "original_path": original_image_path,
                "crop_path": None,
                "bbox": bbox,
                "description": description,
                "status": "UPLOAD_FAILED",
                "created_by": created_by,
            }

        try:
            with Image.open(original_image_path) as img:
                img_w, img_h = img.size
                x = max(0, int(bbox.get("x", 0)))
                y = max(0, int(bbox.get("y", 0)))
                w = max(10, int(bbox.get("width", 100)))
                h = max(10, int(bbox.get("height", 40)))

                x2 = min(img_w, x + w)
                y2 = min(img_h, y + h)

                crop_img = img.crop((x, y, x2, y2))
                crop_w, crop_h = crop_img.size

                # Convert to RGB JPEG high quality
                if crop_img.mode in ("RGBA", "P"):
                    crop_img = crop_img.convert("RGB")

                buf = io.BytesIO()
                crop_img.save(buf, format="JPEG", quality=95)
                crop_bytes = buf.getvalue()

            # Cryptographic SHA-256 hash before upload
            sha256 = self.compute_sha256(crop_bytes)

            # Save local temporary copy on disk
            crop_filename = f"evidence_{evidence_id}_{sha256[:8]}.jpg"
            local_crop_path = os.path.join(storage_manager.evidence_dir, crop_filename)
            with open(local_crop_path, "wb") as f:
                f.write(crop_bytes)

            # Deterministic Public ID:
            # lm_trace/evidence/inspection_{inspection_id}/evidence_{evidence_id}_{sha256[:8]}
            public_id = f"evidence_{evidence_id}_{sha256[:8]}"
            folder = f"{settings.CLOUDINARY_FOLDER}/inspection_{inspection_id}"

            cloud_metadata: Dict[str, Any] = {
                "cloudinary_public_id": None,
                "cloudinary_secure_url": None,
                "cloudinary_resource_type": "image",
                "cloudinary_format": "jpeg",
                "cloudinary_version": None,
                "width": crop_w,
                "height": crop_h,
                "file_size_bytes": len(crop_bytes),
                "sha256": sha256,
                "etag": None,
                "status": "LOCAL_ONLY",
            }

            if settings.CLOUDINARY_ENABLED and settings.cloudinary_configured:
                try:
                    upload_res = await self.storage.upload_evidence_image(
                        file_bytes=crop_bytes,
                        public_id=public_id,
                        folder=folder,
                        tags=["evidence", f"inspection_{inspection_id}", evidence_type.lower()],
                        context={"inspection_id": inspection_id, "evidence_id": evidence_id, "sha256": sha256}
                    )
                    cloud_metadata.update({
                        "cloudinary_public_id": upload_res.public_id,
                        "cloudinary_secure_url": upload_res.secure_url,
                        "cloudinary_resource_type": upload_res.resource_type,
                        "cloudinary_format": upload_res.format or "jpeg",
                        "cloudinary_version": upload_res.version,
                        "width": upload_res.width or crop_w,
                        "height": upload_res.height or crop_h,
                        "file_size_bytes": upload_res.bytes or len(crop_bytes),
                        "etag": upload_res.etag,
                        "status": "STORED",
                    })
                except Exception as upload_err:
                    logger.error("Failed to upload evidence crop %s to Cloudinary: %s", evidence_id, upload_err)
                    cloud_metadata["status"] = "UPLOAD_FAILED"

            return {
                "id": evidence_id,
                "inspection_id": inspection_id,
                "image_id": image_id,
                "finding_id": finding_id,
                "evidence_type": evidence_type,
                "original_path": original_image_path,
                "crop_path": local_crop_path,
                "bbox": bbox,
                "description": description or f"Cropped evidence for {evidence_type}",
                "created_by": created_by,
                **cloud_metadata
            }
        except Exception as e:
            logger.error("Failed to generate evidence crop: %s", e)
            return {
                "id": evidence_id,
                "inspection_id": inspection_id,
                "image_id": image_id,
                "finding_id": finding_id,
                "evidence_type": evidence_type,
                "original_path": original_image_path,
                "crop_path": None,
                "bbox": bbox,
                "description": description,
                "status": "UPLOAD_FAILED",
                "created_by": created_by,
            }

    async def generate_and_store_annotated_overlay(
        self,
        inspection_id: str,
        original_image_path: str,
        findings_with_bboxes: List[Dict[str, Any]],
        image_id: Optional[str] = None,
        created_by: Optional[str] = "SYSTEM_PIPELINE",
    ) -> Optional[Dict[str, Any]]:
        """
        Draws color-coded regulatory bounding boxes on a fresh copy of the original image,
        calculates SHA-256, and uploads the preprocessed annotated overlay to Cloudinary.
        Preserves original image unchanged.
        """
        if not os.path.exists(original_image_path):
            return None

        try:
            img = cv2.imread(original_image_path)
            if img is None:
                return None

            img_h, img_w = img.shape[:2]

            for finding in findings_with_bboxes:
                bbox = finding.get("bbox")
                if not bbox:
                    continue
                x = int(bbox.get("x", 0))
                y = int(bbox.get("y", 0))
                w = int(bbox.get("width", 100))
                h = int(bbox.get("height", 40))

                status = (finding.get("status") or "PASS").upper()
                if "VIOLATION" in status or status == "FAIL":
                    color = (0, 0, 220)  # Red BGR
                elif "REVIEW" in status or "WARN" in status:
                    color = (0, 165, 255)  # Amber BGR
                elif "AI" in status:
                    color = (180, 50, 180)  # Purple BGR
                else:
                    color = (0, 180, 0)  # Green BGR

                cv2.rectangle(img, (x, y), (x + w, y + h), color, 3)

                label = finding.get("label") or finding.get("field_name") or ""
                if label:
                    cv2.putText(img, label, (x, max(20, y - 8)), cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)

            evidence_id = f"ev-overlay-{uuid.uuid4().hex[:8]}"
            local_overlay_name = f"annotated_{inspection_id}_{uuid.uuid4().hex[:8]}.jpg"
            local_overlay_path = os.path.join(storage_manager.evidence_dir, local_overlay_name)

            success, encoded_buf = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), 95])
            if not success:
                return None
            overlay_bytes = encoded_buf.tobytes()

            with open(local_overlay_path, "wb") as f:
                f.write(overlay_bytes)

            sha256 = self.compute_sha256(overlay_bytes)

            public_id = f"evidence_{evidence_id}_{sha256[:8]}"
            folder = f"{settings.CLOUDINARY_FOLDER}/inspection_{inspection_id}"

            cloud_metadata: Dict[str, Any] = {
                "cloudinary_public_id": None,
                "cloudinary_secure_url": None,
                "cloudinary_resource_type": "image",
                "cloudinary_format": "jpeg",
                "cloudinary_version": None,
                "width": img_w,
                "height": img_h,
                "file_size_bytes": len(overlay_bytes),
                "sha256": sha256,
                "etag": None,
                "status": "LOCAL_ONLY",
            }

            if settings.CLOUDINARY_ENABLED and settings.cloudinary_configured:
                try:
                    upload_res = await self.storage.upload_evidence_image(
                        file_bytes=overlay_bytes,
                        public_id=public_id,
                        folder=folder,
                        tags=["evidence", f"inspection_{inspection_id}", "annotated_overlay"],
                        context={"inspection_id": inspection_id, "evidence_id": evidence_id, "sha256": sha256}
                    )
                    cloud_metadata.update({
                        "cloudinary_public_id": upload_res.public_id,
                        "cloudinary_secure_url": upload_res.secure_url,
                        "cloudinary_resource_type": upload_res.resource_type,
                        "cloudinary_format": upload_res.format or "jpeg",
                        "cloudinary_version": upload_res.version,
                        "width": upload_res.width or img_w,
                        "height": upload_res.height or img_h,
                        "file_size_bytes": upload_res.bytes or len(overlay_bytes),
                        "etag": upload_res.etag,
                        "status": "STORED",
                    })
                except Exception as upload_err:
                    logger.error("Failed to upload annotated overlay to Cloudinary: %s", upload_err)
                    cloud_metadata["status"] = "UPLOAD_FAILED"

            return {
                "id": evidence_id,
                "inspection_id": inspection_id,
                "image_id": image_id,
                "finding_id": None,
                "evidence_type": "ANNOTATED_OVERLAY",
                "original_path": original_image_path,
                "crop_path": local_overlay_path,
                "bbox": {"x": 0, "y": 0, "width": img_w, "height": img_h},
                "description": "Full package surface annotated overlay with statutory color-coded bounding boxes",
                "created_by": created_by,
                **cloud_metadata
            }
        except Exception as e:
            logger.warning("Failed to generate annotated evidence overlay: %s", e)
            return None

    async def process_inspection_evidence(
        self,
        inspection_id: str,
        images: List[Dict[str, Any]],
        declarations: List[Dict[str, Any]],
        violations: List[Dict[str, Any]],
        checks: Optional[List[Dict[str, Any]]] = None,
    ) -> List[Dict[str, Any]]:
        """
        Main evidence processing orchestrator.
        Generates and uploads preprocessed crops for all detected declarations and violations,
        plus an annotated overlay for each package surface.
        """
        if not images:
            return []

        evidence_list: List[Dict[str, Any]] = []

        # Map images by ID and surface
        image_map = {img.get("id"): img for img in images if isinstance(img, dict)}
        first_img = images[0] if isinstance(images[0], dict) else {}
        first_img_path = first_img.get("original_path")

        # 1. Generate crops for detected declarations
        for dec in declarations:
            bbox = dec.get("bbox")
            if not bbox or not isinstance(bbox, dict):
                continue
            src_img_id = dec.get("source_image_id")
            src_img = image_map.get(src_img_id) or first_img
            img_path = src_img.get("original_path") or first_img_path
            if not img_path or not os.path.exists(img_path):
                continue

            field_name = (dec.get("field_name") or "declaration").lower()
            ev_type = "DECLARATION_CROP"
            if "mrp" in field_name or "price" in field_name:
                ev_type = "MRP_CROP"
            elif "quantity" in field_name or "net_weight" in field_name:
                ev_type = "DECLARATION_CROP"
            elif "date" in field_name or "month" in field_name:
                ev_type = "DECLARATION_CROP"
            elif "pdp" in field_name or "height" in field_name:
                ev_type = "FONT_SIZE_CROP"

            val = dec.get("verified_value") or dec.get("ai_value") or ""
            desc = f"Evidence crop for {field_name.replace('_', ' ').title()}: '{val}'"

            crop_ev = await self.generate_and_store_crop(
                inspection_id=inspection_id,
                original_image_path=img_path,
                bbox=bbox,
                evidence_type=ev_type,
                image_id=src_img.get("id"),
                description=desc,
            )
            evidence_list.append(crop_ev)

        # 2. Generate crops for findings / violations if bboxes exist
        for viol in violations:
            bbox = viol.get("bbox")
            if not bbox:
                # Check if violation matches a declaration field
                viol_field = viol.get("field") or ""
                matching_dec = next((d for d in declarations if d.get("field_name") == viol_field and d.get("bbox")), None)
                if matching_dec:
                    bbox = matching_dec.get("bbox")

            if bbox and first_img_path and os.path.exists(first_img_path):
                desc = viol.get("ai_explanation") or f"Violation evidence for {viol.get('type', 'rule non-compliance')}"
                viol_ev = await self.generate_and_store_crop(
                    inspection_id=inspection_id,
                    original_image_path=first_img_path,
                    bbox=bbox,
                    evidence_type="VIOLATION_EVIDENCE",
                    finding_id=viol.get("id"),
                    image_id=first_img.get("id"),
                    description=desc,
                )
                evidence_list.append(viol_ev)

        # 3. Generate annotated overlay for primary image
        overlay_findings = []
        for dec in declarations:
            if dec.get("bbox"):
                overlay_findings.append({
                    "bbox": dec["bbox"],
                    "field_name": dec.get("field_name", ""),
                    "status": "PASS" if dec.get("correctness_status") == "VALID" else "REVIEW"
                })
        for viol in violations:
            if viol.get("bbox"):
                overlay_findings.append({
                    "bbox": viol["bbox"],
                    "field_name": viol.get("type", "VIOLATION"),
                    "status": "VIOLATION"
                })

        if first_img_path and os.path.exists(first_img_path) and overlay_findings:
            overlay_ev = await self.generate_and_store_annotated_overlay(
                inspection_id=inspection_id,
                original_image_path=first_img_path,
                findings_with_bboxes=overlay_findings,
                image_id=first_img.get("id"),
            )
            if overlay_ev:
                evidence_list.append(overlay_ev)

        return evidence_list

    async def retry_evidence_upload(
        self,
        evidence_record: Dict[str, Any],
        repository: Any,
    ) -> Dict[str, Any]:
        """
        Safely retries Cloudinary upload for an evidence record without creating duplicates.
        """
        evidence_id = evidence_record.get("id")
        inspection_id = evidence_record.get("inspection_id")

        # Idempotency check: if already STORED, do not upload again
        if evidence_record.get("status") == "STORED" and evidence_record.get("cloudinary_secure_url"):
            logger.info("Evidence %s already stored in Cloudinary; skipping duplicate upload.", evidence_id)
            return evidence_record

        if not settings.CLOUDINARY_ENABLED or not settings.cloudinary_configured:
            raise RuntimeError("Cloudinary is not configured or disabled.")

        crop_path = evidence_record.get("crop_path")
        orig_path = evidence_record.get("original_path")

        file_to_upload = crop_path if (crop_path and os.path.exists(crop_path)) else orig_path
        if not file_to_upload or not os.path.exists(file_to_upload):
            raise FileNotFoundError(f"Local evidence file no longer exists for {evidence_id}")

        with open(file_to_upload, "rb") as f:
            file_bytes = f.read()

        sha256 = self.compute_sha256(file_bytes)
        public_id = f"evidence_{evidence_id}_{sha256[:8]}"
        folder = f"{settings.CLOUDINARY_FOLDER}/inspection_{inspection_id}"

        upload_res = await self.storage.upload_evidence_image(
            file_bytes=file_bytes,
            public_id=public_id,
            folder=folder,
            tags=["evidence", f"inspection_{inspection_id}", "retry"],
            context={"inspection_id": inspection_id, "evidence_id": evidence_id, "sha256": sha256}
        )

        updates = {
            "cloudinary_public_id": upload_res.public_id,
            "cloudinary_secure_url": upload_res.secure_url,
            "cloudinary_resource_type": upload_res.resource_type,
            "cloudinary_format": upload_res.format or "jpeg",
            "cloudinary_version": upload_res.version,
            "width": upload_res.width or evidence_record.get("width"),
            "height": upload_res.height or evidence_record.get("height"),
            "file_size_bytes": upload_res.bytes or len(file_bytes),
            "sha256": sha256,
            "etag": upload_res.etag,
            "status": "STORED",
        }

        updated = await repository.update_evidence(evidence_id, updates)
        return updated or {**evidence_record, **updates}


evidence_service = EvidenceService()
