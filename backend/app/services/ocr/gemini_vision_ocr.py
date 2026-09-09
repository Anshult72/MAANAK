"""Vision-grounded OCR for package images using the configured Gemini model."""
import json
import os
import asyncio
from typing import List

from app.core.config import settings
from app.schemas.domain import BoundingBox, OcrBlock, OcrResult
from app.services.ocr.interface import IOcrService


class GeminiVisionOcrService(IOcrService):
    def __init__(self):
        from google import genai
        self._client = genai.Client(api_key=settings.GEMINI_API_KEY)

    async def extract_text(self, image_path: str, image_id: str, surface_type: str = "FRONT") -> OcrResult:
        if not os.path.isfile(image_path):
            raise ValueError(f"Captured image is unavailable: {image_path}")
        from google.genai import types
        with open(image_path, "rb") as image_file:
            image_bytes = image_file.read()
        mime_type = "image/png" if image_path.lower().endswith(".png") else "image/jpeg"
        prompt = """Read every visible packaging declaration exactly as printed. Return JSON only:
{"lines":[{"text":"...","confidence":0.0}]}. Include product name, net quantity, MRP,
packed/use-by dates, manufacturer/marketer, address, customer-care, barcode and origin.
Do not infer text not visible. Keep every printed line separate."""
        response = None
        last_error = None
        for attempt in range(3):
            try:
                response = self._client.models.generate_content(
                    model=settings.GEMINI_MODEL,
                    contents=[types.Part.from_bytes(data=image_bytes, mime_type=mime_type), prompt],
                    config=types.GenerateContentConfig(response_mime_type="application/json", temperature=0.0),
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
        lines = json.loads(response.text).get("lines", [])
        blocks = [OcrBlock(
            block_id=f"blk-{image_id}-{index + 1}", text=str(line.get("text", "")).strip(),
            confidence=float(line.get("confidence", 0.85)), bbox=BoundingBox(x=0, y=0, width=1, height=1),
            image_id=image_id, surface_type=surface_type,
        ) for index, line in enumerate(lines) if str(line.get("text", "")).strip()]
        if not blocks:
            raise ValueError("No readable text was detected in the captured image.")
        return OcrResult(raw_text="\n".join(block.text for block in blocks), blocks=blocks,
                         confidence=round(sum(block.confidence for block in blocks) / len(blocks), 2), image_id=image_id)

    async def extract_text_from_images(self, image_items: List[dict]) -> List[OcrResult]:
        return [await self.extract_text(item["original_path"], item["id"], item.get("surface_type", "FRONT")) for item in image_items]
