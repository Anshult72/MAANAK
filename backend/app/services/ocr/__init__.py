from app.services.ocr.interface import IOcrService
from app.services.ocr.mock_ocr import MockOcrService
from app.services.ocr.paddle_ocr import PaddleOcrService
from app.services.ocr.gemini_vision_ocr import GeminiVisionOcrService
from app.core.config import settings

def get_ocr_service() -> IOcrService:
    if settings.MOCK_AI_MODE:
        return MockOcrService()
    if settings.GEMINI_API_KEY:
        return GeminiVisionOcrService()
    return PaddleOcrService()
