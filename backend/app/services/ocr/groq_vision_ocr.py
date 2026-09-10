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
            raise FileNotFoundError(f"Captured image is unavailable: {image_path}")
        if os.path.getsize(image_path) > 20 * 1024 * 1024:
            raise ValueError("Captured image is over Groq's 20 MB image-request limit.")

        with open(image_path, "rb") as image_file:
            encoded_image = base64.b64encode(image_file.read()).decode("ascii")
        mime_type = "image/png" if image_path.lower().endswith(".png") else "image/jpeg"
        prompt = (
            "Perform OCR: read every visible line of text in this image exactly as printed. "
            "This can be any package surface, so include all visible text; do not decide whether a line is relevant. "
            "Do not infer or add text that is not visible. "
            "Return exactly valid JSON: {\"lines\":[{\"text\":\"visible text\",\"confidence\":0.9}]} "
            "and use an empty lines array only when the image truly has no readable text."
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
            parsed = json.loads(content)
        except (json.JSONDecodeError, Exception) as error:
            raise RuntimeError("Groq returned an unreadable OCR response. Please retry the analysis.") from error

        if isinstance(parsed, list):
            lines = parsed
        elif isinstance(parsed, dict):
            lines = parsed.get("lines", [])
            if not lines and "text" in parsed:
                lines = [parsed]
        else:
            lines = []

        blocks = []
        for index, line in enumerate(lines):
            text = ""
            conf = 0.85
            if isinstance(line, dict):
                text = str(line.get("text", "")).strip()
                conf = float(line.get("confidence", 0.85))
            elif isinstance(line, str):
                text = line.strip()
            elif isinstance(line, (list, tuple)):
                text = " ".join(str(item).strip() for item in line if str(item).strip())

            if text:
                blocks.append(
                    OcrBlock(
                        block_id=f"blk-{image_id}-{index + 1}",
                        text=text,
                        confidence=conf,
                        bbox=BoundingBox(x=0, y=0, width=1, height=1),
                        image_id=image_id,
                        surface_type=surface_type,
                    )
                )
        if not blocks:
            return OcrResult(
                raw_text="",
                blocks=[],
                confidence=0.0,
                image_id=image_id,
            )
        return OcrResult(
            raw_text="\n".join(block.text for block in blocks),
            blocks=blocks,
            confidence=round(sum(block.confidence for block in blocks) / len(blocks), 2),
            image_id=image_id,
        )

    async def extract_text_from_images(self, image_items: List[dict]) -> List[OcrResult]:
        existing_items = [item for item in image_items if item.get("original_path") and os.path.isfile(item["original_path"])]
        if not existing_items:
            raise RuntimeError(
                "Captured package images are no longer available in server storage. Please re-capture or re-upload the package photos."
            )
        return [
            await self.extract_text(
                item["original_path"], item["id"], item.get("surface_type", "FRONT")
            )
            for item in existing_items
        ]
