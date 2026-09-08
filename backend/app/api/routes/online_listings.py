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

router = APIRouter(prefix="/api/listings", tags=["Online Listings"])

def get_utc_now_iso():
    return datetime.now(timezone.utc).isoformat()

@router.post("/analyze")
async def analyze_online_listing(
    url: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    user_payload: dict = Depends(get_current_user_payload)
):
    """
    Analyzes an e-commerce product listing via uploaded screenshot (primary reliable SIH demo path)
    or safe SSRF-guarded URL.
    """
    screenshot_path = "storage/listing_snapshots/demo_listing.png"
    if file:
        file_bytes = await file.read()
        listing_id = uuid.uuid4().hex[:8]
        screenshot_path, _, _, _, _ = await storage_manager.save_inspection_image(
            f"listing-{listing_id}", file_bytes, file.filename or "listing.png"
        )
    elif url:
        is_safe, msg = online_listing_service.validate_url_security(url)
        if not is_safe:
            raise HTTPException(status_code=400, detail=msg)
    else:
        raise HTTPException(status_code=400, detail="Provide either a screenshot image or a valid product listing URL.")

    # Execute pipeline on listing
    ocr_service = get_ocr_service()
    ocr_res = await ocr_service.extract_text(screenshot_path, "img-listing-01", surface_type="FRONT")

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
        "source_type": "SCREENSHOT" if file else "URL",
        "url": url,
        "screenshot_path": screenshot_path,
        "extracted_declarations": extracted.model_dump(),
        "assessment": assessment.model_dump(),
        "matrix": correctness.get("matrix", [])
    }
