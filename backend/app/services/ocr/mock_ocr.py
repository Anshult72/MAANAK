from typing import List
from app.services.ocr.interface import IOcrService
from app.schemas.domain import OcrResult, OcrBlock, BoundingBox

class MockOcrService(IOcrService):
    async def extract_text(self, image_path: str, image_id: str, surface_type: str = "FRONT") -> OcrResult:
        blocks = []
        surface_upper = (surface_type or "FRONT").upper()

        if surface_upper == "FRONT":
            blocks = [
                OcrBlock(
                    block_id=f"blk-{image_id}-1",
                    text="ABC Premium Basmati Rice",
                    confidence=0.98,
                    bbox=BoundingBox(x=120, y=180, width=640, height=75),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-2",
                    text="Royal Aged Heritage Grains",
                    confidence=0.95,
                    bbox=BoundingBox(x=150, y=270, width=450, height=45),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-3",
                    text="Net Weight: 5 kg",
                    confidence=0.99,
                    bbox=BoundingBox(x=140, y=850, width=280, height=55),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-4",
                    text="100% Pure Indian Basmati",
                    confidence=0.94,
                    bbox=BoundingBox(x=140, y=930, width=350, height=40),
                    image_id=image_id,
                    surface_type=surface_type
                )
            ]
        elif surface_upper in ["BACK", "MRP_AREA"]:
            blocks = [
                OcrBlock(
                    block_id=f"blk-{image_id}-10",
                    text="MRP ₹ 450.00 (Inclusive of all taxes)",
                    confidence=0.99,
                    bbox=BoundingBox(x=80, y=150, width=520, height=52),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-11",
                    text="Unit Sale Price: ₹ 90.00 / kg",
                    confidence=0.97,
                    bbox=BoundingBox(x=80, y=215, width=380, height=45),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-12",
                    text="Packed on: 08/2026",
                    confidence=0.98,
                    bbox=BoundingBox(x=80, y=275, width=260, height=40),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-13",
                    text="Best Before: 24 months from packaging",
                    confidence=0.96,
                    bbox=BoundingBox(x=80, y=330, width=420, height=42),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-14",
                    text="Manufactured & Packed by: ABC Agro Foods Ltd., Plot 42, Food Industrial Estate, Karnal, Haryana - 132001",
                    confidence=0.96,
                    bbox=BoundingBox(x=80, y=410, width=780, height=85),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-15",
                    text="Customer Care: 1800-111-2222 | care@abcagro.com",
                    confidence=0.98,
                    bbox=BoundingBox(x=80, y=520, width=560, height=48),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-16",
                    text="Country of Origin: India",
                    confidence=0.99,
                    bbox=BoundingBox(x=80, y=585, width=320, height=44),
                    image_id=image_id,
                    surface_type=surface_type
                )
            ]
        else:
            blocks = [
                OcrBlock(
                    block_id=f"blk-{image_id}-20",
                    text="Barcode: 8901234567890",
                    confidence=0.99,
                    bbox=BoundingBox(x=100, y=100, width=300, height=60),
                    image_id=image_id,
                    surface_type=surface_type
                ),
                OcrBlock(
                    block_id=f"blk-{image_id}-21",
                    text="Batch No: BAS-AUG-2026-04",
                    confidence=0.97,
                    bbox=BoundingBox(x=100, y=180, width=360, height=45),
                    image_id=image_id,
                    surface_type=surface_type
                )
            ]

        raw_text = "\n".join([b.text for b in blocks])
        avg_conf = sum([b.confidence for b in blocks]) / max(1, len(blocks))
        return OcrResult(raw_text=raw_text, blocks=blocks, confidence=avg_conf, image_id=image_id)

    async def extract_text_from_images(self, image_items: List[dict]) -> List[OcrResult]:
        results = []
        for item in image_items:
            path = item.get("original_path", "")
            img_id = item.get("id", "img-unknown")
            surface = item.get("surface_type", "FRONT")
            res = await self.extract_text(path, img_id, surface)
            results.append(res)
        return results
