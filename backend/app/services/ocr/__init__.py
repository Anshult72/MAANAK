from app.services.ocr.interface import IOcrService
from app.services.ocr.mock_ocr import MockOcrService
from app.services.ocr.paddle_ocr import PaddleOcrService
from app.services.ocr.groq_vision_ocr import GroqVisionOcrService
from app.core.config import settings

def get_ocr_service() -> IOcrService:
    if settings.MOCK_AI_MODE:
        return MockOcrService()
    if settings.GROQ_API_KEY:
        return GroqVisionOcrService()
    return PaddleOcrService()
