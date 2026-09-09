"""Vision-grounded OCR for package images using Groq's vision API."""
import asyncio
import base64
import json
import os
from typing import List

from app.core.config import settings
from app.schemas.domain import BoundingBox, OcrBlock, OcrResult
from app.services.ocr.interface import IOcrService


class GroqVisionOcrService(IOcrService):
    def __init__(self):
        from groq import Groq

        if not settings.GROQ_API_KEY:
            raise RuntimeError("GROQ_API_KEY is not configured.")
        self._client = Groq(api_key=settings.GROQ_API_KEY)

    async def extract_text(
        self, image_path: str, image_id: str, surface_type: str = "FRONT"
    ) -> OcrResult:
        if not os.path.isfile(image_path):
            raise ValueError(f"Captured image is unavailable: {image_path}")
        if os.path.getsize(image_path) > 20 * 1024 * 1024:
            raise ValueError("Captured image is over Groq's 20 MB image-request limit.")

        with open(image_path, "rb") as image_file:
            encoded_image = base64.b64encode(image_file.read()).decode("ascii")
        mime_type = "image/png" if image_path.lower().endswith(".png") else "image/jpeg"
        prompt = (
            "Read every visible packaging declaration exactly as printed. "
            "Include product name, net quantity, MRP, packed/use-by dates, manufacturer/marketer, "
            "address, customer-care, barcode and origin. Do not infer text not visible. "
            "Return exactly valid JSON: {\"lines\":[{\"text\":\"visible text\",\"confidence\":0.9}]}."
        )

        response = None
        last_error = None
        for attempt in range(3):
            try:
                response = self._client.chat.completions.create(
                    model=settings.GROQ_VISION_MODEL,
                    messages=[{
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {"type": "image_url", "image_url": {
                                "url": f"data:{mime_type};base64,{encoded_image}"
                            }},
                        ],
                    }],
                    response_format={"type": "json_object"},
                    temperature=0,
                    max_completion_tokens=1000,
                )
                break
            except Exception as error:
                last_error = error
                if attempt < 2:
                    await asyncio.sleep(2 ** attempt)

        if response is None:
            raise RuntimeError(
                "Live image OCR is temporarily unavailable. Please retry the analysis; no demo data was used."
            ) from last_error

        content = response.choices[0].message.content or "{}"
        try:
            lines = json.loads(content).get("lines", [])
        except json.JSONDecodeError as error:
            raise RuntimeError("Groq returned an unreadable OCR response. Please retry the analysis.") from error

        blocks = [
            OcrBlock(
                block_id=f"blk-{image_id}-{index + 1}",
                text=str(line.get("text", "")).strip(),
                confidence=float(line.get("confidence", 0.85)),
                # Groq text extraction does not return reliable pixel boxes.
                bbox=BoundingBox(x=0, y=0, width=1, height=1),
                image_id=image_id,
                surface_type=surface_type,
            )
            for index, line in enumerate(lines)
            if isinstance(line, dict) and str(line.get("text", "")).strip()
        ]
        if not blocks:
            raise ValueError("No readable text was detected in the captured image.")
        return OcrResult(
            raw_text="\n".join(block.text for block in blocks),
            blocks=blocks,
            confidence=round(sum(block.confidence for block in blocks) / len(blocks), 2),
            image_id=image_id,
        )

    async def extract_text_from_images(self, image_items: List[dict]) -> List[OcrResult]:
        return [
            await self.extract_text(
                item["original_path"], item["id"], item.get("surface_type", "FRONT")
            )
            for item in image_items
        ]
