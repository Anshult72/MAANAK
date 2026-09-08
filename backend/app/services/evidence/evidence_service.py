import os
import cv2
import numpy as np
from typing import List, Dict, Any, Optional
from app.storage.file_storage import storage_manager
from app.core.logging import logger

class EvidenceService:
    @staticmethod
    async def generate_annotated_image(
        original_image_path: str,
        findings_with_bboxes: List[Dict[str, Any]],
        output_image_path: str
    ) -> Optional[str]:
        """
        Draws color-coded bounding boxes on a copy of the original image:
        - Green: PASS / Detected (0, 200, 0)
        - Amber: REVIEW (0, 165, 255)
        - Red: POTENTIAL_VIOLATION (0, 0, 220)
        - Purple: AI Candidate (180, 50, 180)
        Preserves original image unchanged!
        """
        if not os.path.exists(original_image_path):
            return None

        try:
            img = cv2.imread(original_image_path)
            if img is None:
                return None

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

            os.makedirs(os.path.dirname(output_image_path), exist_ok=True)
            cv2.imwrite(output_image_path, img)
            return output_image_path
        except Exception as e:
            logger.warning(f"Failed to generate annotated evidence image: {e}")
            return None

evidence_service = EvidenceService()
