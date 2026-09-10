"""OCR-grounded declaration normalization using Groq."""
import json
from typing import Any, Dict, List

from app.core.config import settings
from app.schemas.domain import ExtractedDeclarationsPayload, OcrResult, SemanticDeclarationField
from app.services.llm.gemini_llm import ALL_DECLARATION_FIELDS, SYSTEM_PROMPT, GeminiLlmService
from app.services.llm.interface import ILlmService


class GroqLlmService(ILlmService):
    def __init__(self):
        from groq import Groq

        if not settings.GROQ_API_KEY:
            raise RuntimeError("GROQ_API_KEY is not configured.")
        self._client = Groq(api_key=settings.GROQ_API_KEY)

    async def extract_declarations(
        self, ocr_results: List[OcrResult], product_category: str = "Packaged Food"
    ) -> ExtractedDeclarationsPayload:
        block_map = {}
        ocr_payload = []
        for result in ocr_results:
            blocks = []
            for block in result.blocks:
                block_map[block.block_id] = block
                blocks.append({"id": block.block_id, "text": block.text, "surface": block.surface_type})
            ocr_payload.append({"image_id": result.image_id, "blocks": blocks})

        prompt = f"{SYSTEM_PROMPT}\nProduct Category: {product_category}\nOCR Blocks:\n{json.dumps(ocr_payload)}"
        try:
            response = self._client.chat.completions.create(
                model=settings.GROQ_TEXT_MODEL,
                messages=[{"role": "system", "content": SYSTEM_PROMPT}, {"role": "user", "content": prompt}],
                response_format={"type": "json_object"},
                temperature=0,
                max_completion_tokens=1600,
            )
            parsed = json.loads(response.choices[0].message.content or "{}")
            if isinstance(parsed, dict):
                if isinstance(parsed.get("declarations"), dict):
                    raw_dict = parsed["declarations"]
                elif isinstance(parsed.get("declarations"), list):
                    raw_dict = {
                        item["field_name"]: item
                        for item in parsed["declarations"]
                        if isinstance(item, dict) and "field_name" in item
                    }
                else:
                    raw_dict = parsed
            elif isinstance(parsed, list):
                raw_dict = {
                    item["field_name"]: item
                    for item in parsed
                    if isinstance(item, dict) and "field_name" in item
                }
            else:
                raw_dict = {}
        except Exception:
            # Preserve the evidence-first behaviour even if a text model is busy.
            return GeminiLlmService._extract_from_real_ocr(ocr_results)

        constructed: Dict[str, Any] = {}
        for field_name in ALL_DECLARATION_FIELDS:
            value = raw_dict.get(field_name) if isinstance(raw_dict, dict) else None
            if isinstance(value, dict) and value.get("value"):
                source_id = value.get("source_block_id")
                source = block_map.get(source_id)
                constructed[field_name] = SemanticDeclarationField(
                    field_name=field_name,
                    value=str(value["value"]),
                    normalized_value=str(value.get("normalized_value") or value["value"]),
                    unit=value.get("unit"),
                    canonical_unit=value.get("canonical_unit") or value.get("unit"),
                    confidence=float(value.get("confidence", 0.90)),
                    source_block_id=source_id,
                    source_image_id=source.image_id if source else None,
                    source_text=value.get("source_text") or (source.text if source else None),
                    bbox=source.bbox if source else None,
                    provenance="AI_EXTRACTED",
                )
            else:
                constructed[field_name] = None
        return ExtractedDeclarationsPayload(**constructed)
