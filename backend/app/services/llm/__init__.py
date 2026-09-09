from app.services.llm.interface import ILlmService
from app.services.llm.mock_llm import MockLlmService
from app.services.llm.groq_llm import GroqLlmService
from app.core.config import settings

def get_llm_service() -> ILlmService:
    if settings.MOCK_AI_MODE:
        return MockLlmService()
    if settings.GROQ_API_KEY:
        return GroqLlmService()
    # With no cloud key, use the existing local OCR-only parser rather than
    # silently returning demo declarations.
    return _OcrOnlyLlmService()


class _OcrOnlyLlmService(ILlmService):
    async def extract_declarations(self, ocr_results, product_category="Packaged Food"):
        from app.services.llm.gemini_llm import GeminiLlmService
        return GeminiLlmService._extract_from_real_ocr(ocr_results)
