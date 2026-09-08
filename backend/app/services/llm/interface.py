from abc import ABC, abstractmethod
from typing import List
from app.schemas.domain import OcrResult, ExtractedDeclarationsPayload

class ILlmService(ABC):
    @abstractmethod
    async def extract_declarations(
        self,
        ocr_results: List[OcrResult],
        product_category: str = "Packaged Food"
    ) -> ExtractedDeclarationsPayload:
        """
        Normalizes OCR results into structured semantic declarations referencing OCR block IDs.
        Does not invent bounding boxes or make legal compliance determinations.
        """
        pass
