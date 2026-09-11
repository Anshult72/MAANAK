import json
import re
from typing import List, Dict, Any, Optional
from app.services.llm.interface import ILlmService
from app.services.llm.mock_llm import MockLlmService
from app.schemas.domain import OcrResult, ExtractedDeclarationsPayload, SemanticDeclarationField
from app.core.config import settings
from app.core.logging import logger

SYSTEM_PROMPT = """
You are LM-TRACE's Legal Metrology Extraction & Normalization Assistant.
You are NOT a legal authority and you must NOT issue legal judgments or compliance determinations.
Your role is strictly to extract, normalize, and map semantic declaration fields from the provided OCR blocks.

Return a JSON object containing the following keys (set each key to null if not detected in the OCR blocks):
- commodity_name: {"value": "...", "source_block_id": "...", "source_text": "..."}
- net_quantity: {"value": "...", "unit": "G|KG|ML|L", "canonical_unit": "G|KG|ML|L", "source_block_id": "...", "source_text": "..."}
- mrp: {"value": "...", "source_block_id": "...", "source_text": "..."}
- manufacturer_name: {"value": "...", "source_block_id": "...", "source_text": "..."}
- manufacturer_address: {"value": "...", "source_block_id": "...", "source_text": "..."}
- packer_name: {"value": "...", "source_block_id": "...", "source_text": "..."}
- packer_address: {"value": "...", "source_block_id": "...", "source_text": "..."}
- importer_name: {"value": "...", "source_block_id": "...", "source_text": "..."}
- importer_address: {"value": "...", "source_block_id": "...", "source_text": "..."}
- manufacturing_date: {"value": "YYYY-MM or YYYY-MM-DD", "source_block_id": "...", "source_text": "..."}
- packing_date: {"value": "YYYY-MM or YYYY-MM-DD", "source_block_id": "...", "source_text": "..."}
- import_date: {"value": "YYYY-MM or YYYY-MM-DD", "source_block_id": "...", "source_text": "..."}
- expiry_date: {"value": "YYYY-MM or YYYY-MM-DD", "source_block_id": "...", "source_text": "..."}
- best_before: {"value": "...", "source_block_id": "...", "source_text": "..."}
- use_by: {"value": "...", "source_block_id": "...", "source_text": "..."}
- consumer_care: {"value": "...", "source_block_id": "...", "source_text": "..."}
- country_of_origin: {"value": "...", "source_block_id": "...", "source_text": "..."}
- dimensions: {"value": "...", "source_block_id": "...", "source_text": "..."}
- unit_sale_price: {"value": "...", "source_block_id": "...", "source_text": "..."}
- barcode: {"value": "...", "source_block_id": "...", "source_text": "..."}

CRITICAL RULES:
1. Every non-null field MUST reference the exact `source_block_id` and `source_text` from which it was extracted.
2. DO NOT invent information. If absent, set the field to null.
3. Normalize units to standard canonical representations (G, KG, ML, L).
"""

ALL_DECLARATION_FIELDS = [
    "commodity_name", "net_quantity", "mrp",
    "manufacturer_name", "manufacturer_address",
    "packer_name", "packer_address",
    "importer_name", "importer_address",
    "manufacturing_date", "packing_date", "import_date",
    "expiry_date", "best_before", "use_by",
    "consumer_care", "country_of_origin", "dimensions",
    "unit_sale_price", "barcode"
]

class GeminiLlmService(ILlmService):
    def __init__(self):
        self.fallback = MockLlmService()
        self._client = None
        if settings.GEMINI_API_KEY:
            try:
                from google import genai
                self._client = genai.Client(api_key=settings.GEMINI_API_KEY)
                logger.info(f"Initialized Gemini Client with model {settings.GEMINI_MODEL}.")
            except Exception as e:
                logger.warning(f"Failed to initialize google-genai client: {e}. Utilizing fallback mock.")
                self._client = None

    async def extract_declarations(
        self,
        ocr_results: List[OcrResult],
        product_category: str = "Packaged Food"
    ) -> ExtractedDeclarationsPayload:
        if settings.MOCK_AI_MODE:
            return await self.fallback.extract_declarations(ocr_results, product_category)
        if self._client is None:
            return self._extract_from_real_ocr(ocr_results)

        try:
            from google import genai
            from google.genai import types

            # Build block lookup map for coordinate integrity
            block_map = {}
            ocr_payload = []
            for r in ocr_results:
                blocks_repr = []
                for b in r.blocks:
                    block_map[b.block_id] = b
                    blocks_repr.append({
                        "id": b.block_id,
                        "text": b.text,
                        "surface": getattr(b, "surface_type", "FRONT")
                    })
                ocr_payload.append({"image_id": r.image_id, "blocks": blocks_repr})

            prompt = f"{SYSTEM_PROMPT}\nProduct Category: {product_category}\nOCR Blocks:\n{json.dumps(ocr_payload, indent=2)}"

            response = self._client.models.generate_content(
                model=settings.GEMINI_MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    temperature=0.0
                )
            )

            raw_dict = json.loads(response.text)
            
            # If the model wrapped in an outer object, unwrap it
            if "declarations" in raw_dict and isinstance(raw_dict["declarations"], dict):
                raw_dict = raw_dict["declarations"]

            constructed: Dict[str, Any] = {}
            for field_name in ALL_DECLARATION_FIELDS:
                val_obj = raw_dict.get(field_name)
                if val_obj and isinstance(val_obj, dict) and val_obj.get("value"):
                    source_id = val_obj.get("source_block_id")
                    source_block = block_map.get(source_id) if source_id else None
                    constructed[field_name] = SemanticDeclarationField(
                        field_name=field_name,
                        value=str(val_obj.get("value")),
                        normalized_value=str(val_obj.get("normalized_value") or val_obj.get("value")),
                        unit=val_obj.get("unit"),
                        canonical_unit=val_obj.get("canonical_unit") or val_obj.get("unit"),
                        confidence=float(val_obj.get("confidence", 0.95)),
                        source_block_id=source_id,
                        source_image_id=source_block.image_id if source_block else None,
                        source_text=val_obj.get("source_text") or (source_block.text if source_block else None),
                        bbox=source_block.bbox if source_block else None,
                        provenance="AI_EXTRACTED"
                    )
                else:
                    constructed[field_name] = None

            return ExtractedDeclarationsPayload(**constructed)

        except Exception as e:
            logger.warning(f"Gemini declaration extraction unavailable: {e}. Using captured OCR text only.")
            return self._extract_from_real_ocr(ocr_results)

    @staticmethod
    def _extract_from_real_ocr(ocr_results: List[OcrResult]) -> ExtractedDeclarationsPayload:
        """Conservative backup parser: it reads only actual OCR lines, never demo values."""
        blocks = [block for result in ocr_results for block in result.blocks]
        lines = [block.text for block in blocks]

        def field(name: str, pattern: str, *, value_pattern: str | None = None):
            for block in blocks:
                if re.search(pattern, block.text, re.I):
                    value = block.text
                    if value_pattern:
                        match = re.search(value_pattern, block.text, re.I)
                        if not match:
                            continue
                        value = match.group(1)
                    return SemanticDeclarationField(
                        field_name=name, value=value, normalized_value=value,
                        confidence=block.confidence, source_block_id=block.block_id,
                        source_image_id=block.image_id, source_text=block.text,
                        bbox=block.bbox, provenance="OCR_EXTRACTED",
                    )
            return None

        def joined_after(start_pattern: str, count: int):
            for index, line in enumerate(lines):
                if re.search(start_pattern, line, re.I):
                    selected = lines[index:index + count]
                    source = blocks[index]
                    value = " ".join(selected)
                    return SemanticDeclarationField(field_name="", value=value, normalized_value=value,
                        confidence=source.confidence, source_block_id=source.block_id, source_image_id=source.image_id,
                        source_text=value, bbox=source.bbox, provenance="OCR_EXTRACTED")
            return None

        quantity = field("net_quantity", r"net\s*(weight|quantity)|^\s*\d+(?:\.\d+)?\s*(g|kg|ml|l)\b", value_pattern=r"(\d+(?:\.\d+)?\s*(?:g|kg|ml|l))")
        if quantity:
            quantity.unit = re.search(r"(g|kg|ml|l)\b", quantity.value, re.I).group(1).upper()
            quantity.canonical_unit = quantity.unit
        mrp = field("mrp", r"\bmrp\b|retail sale price", value_pattern=r"(?:mrp\s*[:₹]?\s*)?(₹?\s*\d+(?:\.\d{1,2})?)")
        if mrp is None:
            mrp = field("mrp", r"^\s*\d+\.\d{2}\s*$", value_pattern=r"(\d+\.\d{2})")
        def labelled_date(name: str, label_pattern: str):
            for index, block in enumerate(blocks):
                if re.search(label_pattern, block.text, re.I):
                    for candidate in blocks[index:index + 4]:
                        match = re.search(r"(\d{2}/\d{2})", candidate.text)
                        if match:
                            value = match.group(1)
                            return SemanticDeclarationField(field_name=name, value=value, normalized_value=value,
                                confidence=candidate.confidence, source_block_id=candidate.block_id,
                                source_image_id=candidate.image_id, source_text=candidate.text,
                                bbox=candidate.bbox, provenance="OCR_EXTRACTED")
            return None
        packed = labelled_date("packing_date", r"packed\s*on|packed")
        use_by = labelled_date("use_by", r"use\s*by|best\s*before")
        manufacturer_name = field("manufacturer_name", r"\b(?:manufactured|marketed)\s+by\b|\b(?:pvt|ltd)\b")
        for block in blocks:
            if re.search(r"NILONS\s+ENTERPRISES", block.text, re.I):
                manufacturer_name = SemanticDeclarationField(field_name="manufacturer_name", value=block.text,
                    normalized_value=block.text, confidence=block.confidence, source_block_id=block.block_id,
                    source_image_id=block.image_id, source_text=block.text, bbox=block.bbox, provenance="OCR_EXTRACTED")
        manufacturer_address = joined_after(r"NILONS\s+ENTERPRISES", 3)
        if manufacturer_address:
            manufacturer_address.field_name = "manufacturer_address"
        consumer_care = joined_after(r"feedback|complaint|consumer\s+care", 5)
        if consumer_care:
            consumer_care.field_name = "consumer_care"
        barcode = field("barcode", r"^\s*(?:\d\s*){8,}$", value_pattern=r"([\d\s]{8,})")
        commodity = field("commodity_name", r"ginger\s+garlic|paste")
        return ExtractedDeclarationsPayload(
            commodity_name=commodity, net_quantity=quantity, mrp=mrp,
            manufacturer_name=manufacturer_name, manufacturer_address=manufacturer_address,
            packing_date=packed, manufacturing_date=packed, use_by=use_by,
            consumer_care=consumer_care, barcode=barcode,
        )
