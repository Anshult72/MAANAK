from abc import ABC, abstractmethod
from typing import List
from app.schemas.domain import OcrResult

class IOcrService(ABC):
    @abstractmethod
    async def extract_text(self, image_path: str, image_id: str, surface_type: str = "FRONT") -> OcrResult:
        """Extract text blocks with coordinates from a single image"""
        pass

    @abstractmethod
    async def extract_text_from_images(self, image_items: List[dict]) -> List[OcrResult]:
        """Extract text from multiple package surface images"""
        pass
