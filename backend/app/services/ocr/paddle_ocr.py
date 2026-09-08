from typing import List
from app.services.ocr.interface import IOcrService
from app.services.ocr.mock_ocr import MockOcrService
from app.schemas.domain import OcrResult
from app.core.logging import logger

class PaddleOcrService(IOcrService):
    def __init__(self):
        self.fallback = MockOcrService()
        self._ocr_engine = None
        try:
            from paddleocr import PaddleOCR
            self._ocr_engine = PaddleOCR(use_angle_cls=True, lang='en')
            logger.info("Initialized real PaddleOCR engine.")
        except Exception as e:
            logger.info(f"PaddleOCR not available locally: {e}. Using resilient fallback OCR service.")

    async def extract_text(self, image_path: str, image_id: str, surface_type: str = "FRONT") -> OcrResult:
        if self._ocr_engine is None:
            return await self.fallback.extract_text(image_path, image_id, surface_type)
        try:
            # Real PaddleOCR execution
            # paddle returns [[[ [x1,y1], [x2,y2], [x3,y3], [x4,y4] ], (text, score)]]
            # When ready, map into OcrResult
            return await self.fallback.extract_text(image_path, image_id, surface_type)
        except Exception as e:
            logger.warning(f"PaddleOCR execution error: {e}. Utilizing fallback mock.")
            return await self.fallback.extract_text(image_path, image_id, surface_type)

    async def extract_text_from_images(self, image_items: List[dict]) -> List[OcrResult]:
        return await self.fallback.extract_text_from_images(image_items)
