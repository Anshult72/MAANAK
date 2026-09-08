from app.services.llm.interface import ILlmService
from app.services.llm.mock_llm import MockLlmService
from app.services.llm.gemini_llm import GeminiLlmService
from app.core.config import settings

def get_llm_service() -> ILlmService:
    if settings.MOCK_AI_MODE or not settings.GEMINI_API_KEY:
        return MockLlmService()
    return GeminiLlmService()
