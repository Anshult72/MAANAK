import uuid
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from typing import Dict, Any, Optional
from app.services.listing.listing_service import online_listing_service
from app.services.ocr import get_ocr_service
from app.services.llm import get_llm_service
from app.services.declaration.correctness_service import declaration_correctness_service
from app.engines.compliance_engine.compliance_engine import compliance_engine
from app.storage.file_storage import storage_manager
from app.core.security import get_current_user_payload
from app.repositories import get_repository
from app.schemas.domain import OcrResult, OcrBlock, BoundingBox

router = APIRouter(prefix="/api/listings", tags=["Online Listings"])

def get_utc_now_iso():
    return datetime.now(timezone.utc).isoformat()

def _ocr_from_listing_text(text: str) -> OcrResult:
    """Build a synthetic OCR result from fetched listing HTML/text preview."""
    clipped = (text or "").strip()[:2000]
    return OcrResult(
        raw_text=clipped,
        blocks=[
            OcrBlock(
                block_id="blk-listing-url-1",
                text=clipped[:800] if clipped else "(empty listing preview)",
                confidence=0.7,
                bbox=BoundingBox(x=0, y=0, width=100, height=100),
                image_id="img-listing-url",
                surface_type="FRONT",
            )
        ],
        confidence=0.7,
        image_id="img-listing-url",
    )

@router.post("/analyze")
async def analyze_online_listing(
    url: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    user_payload: dict = Depends(get_current_user_payload)
):
    """
    Analyzes an e-commerce product listing via uploaded screenshot (primary reliable SIH demo path)
    or safe SSRF-guarded URL (text preview → declaration extraction).
    """
    screenshot_path = None
    ocr_res: Optional[OcrResult] = None
    source_type = "SCREENSHOT"

    if file:
        file_bytes = await file.read()
        listing_id = uuid.uuid4().hex[:8]
        screenshot_path, _, _, _, _ = await storage_manager.save_inspection_image(
            f"listing-{listing_id}", file_bytes, file.filename or "listing.png"
        )
        ocr_service = get_ocr_service()
        ocr_res = await ocr_service.extract_text(screenshot_path, "img-listing-01", surface_type="FRONT")
        source_type = "SCREENSHOT"
    elif url:
        is_safe, msg = online_listing_service.validate_url_security(url)
        if not is_safe:
            raise HTTPException(status_code=400, detail=msg)
        preview = await online_listing_service.fetch_listing_preview(url)
        text_preview = (preview or {}).get("text_preview") or ""
        if not text_preview.strip():
            err = (preview or {}).get("error") or (preview or {}).get("status") or "no text"
            raise HTTPException(
                status_code=400,
                detail=f"Could not extract listing text from URL ({err}). Upload a screenshot instead.",
            )
        ocr_res = _ocr_from_listing_text(text_preview)
        source_type = "URL"
    else:
        raise HTTPException(status_code=400, detail="Provide either a screenshot image or a valid product listing URL.")

    llm_service = get_llm_service()
    extracted = await llm_service.extract_declarations([ocr_res], product_category="Packaged Food")

    correctness = declaration_correctness_service.evaluate_correctness(extracted, ocr_res.blocks, is_imported=False)

    context = {
        "inspectionDate": get_utc_now_iso(),
        "productCategory": "Packaged Food",
        "isEcommerce": True,
        "isImported": False,
        "inspectionChannel": "ECOMMERCE",
        "calibrationStatus": "NOT_CALIBRATED"
    }

    assessment = await compliance_engine.evaluate_compliance(
        extracted_declarations=extracted.model_dump(),
        correctness_data=correctness,
        context=context
    )

    repo = get_repository()
    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "ONLINE_LISTING_ANALYZED",
        "resource_type": "ONLINE_LISTING",
        "resource_id": f"list-{uuid.uuid4().hex[:8]}",
        "metadata": {"url": url, "overall_status": assessment.overall_status}
    })

    return {
        "success": True,
        "source_type": source_type,
        "url": url,
        "screenshot_path": screenshot_path,
        "extracted_declarations": extracted.model_dump(),
        "assessment": assessment.model_dump(),
        "matrix": correctness.get("matrix", [])
    }
