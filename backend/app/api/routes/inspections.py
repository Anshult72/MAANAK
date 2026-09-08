import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from app.schemas.domain import (
    InspectionCreate, InspectionUpdate, InspectionResponse, ImageResponse,
    ComplianceAssessmentResponse
)
from app.repositories import get_repository
from app.core.security import get_current_user_payload
from app.storage.file_storage import storage_manager
from app.services.vision.cv_service import cv_service
from app.services.ocr import get_ocr_service
from app.services.llm import get_llm_service
from app.services.declaration.correctness_service import declaration_correctness_service
from app.engines.compliance_engine.compliance_engine import compliance_engine
from app.services.evidence.evidence_service import evidence_service
from app.core.logging import logger

router = APIRouter(prefix="/api/inspections", tags=["Inspections"])

def get_utc_now_iso():
    return datetime.now(timezone.utc).isoformat()

@router.post("", response_model=Dict[str, Any])
async def create_inspection(
    req: InspectionCreate,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    code_suffix = uuid.uuid4().hex[:5].upper()
    inspection_code = f"INS-2026-{code_suffix}"
    
    ins_data = {
        "id": f"ins-{uuid.uuid4().hex[:12]}",
        "inspection_code": inspection_code,
        "inspector_id": user_payload["sub"],
        "product_id": None,
        "inspection_type": req.inspection_type,
        "inspection_date": get_utc_now_iso(),
        "location": req.location,
        "seller_name": req.seller_name,
        "business_name": req.business_name,
        "status": "DRAFT",
        "score": None,
        "package_type": "RECTANGULAR",
        "package_construction_type": "NORMAL",
        "calibration_status": "NOT_CALIBRATED",
        "notes": req.notes
    }

    created = await repo.create(ins_data)

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "INSPECTION_CREATED",
        "resource_type": "INSPECTION",
        "resource_id": created["id"],
        "new_value": {"code": inspection_code, "location": req.location}
    })

    return created

@router.get("", response_model=List[Dict[str, Any]])
async def list_inspections(
    status: Optional[str] = None,
    query: Optional[str] = None,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    # If inspector, filter own unless supervisor/admin
    inspector_id = user_payload["sub"] if user_payload["role"] == "INSPECTOR" else None
    return await repo.list_inspections(inspector_id=inspector_id, status=status, query=query)

@router.get("/{inspection_id}", response_model=Dict[str, Any])
async def get_inspection(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")
    return ins

@router.patch("/{inspection_id}", response_model=Dict[str, Any])
async def update_inspection(
    inspection_id: str,
    req: Dict[str, Any],
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if ins.get("status") == "FINALIZED":
        raise HTTPException(status_code=400, detail="Cannot modify a finalized inspection")

    updated = await repo.update(inspection_id, req)
    return updated

@router.post("/{inspection_id}/images", response_model=Dict[str, Any])
async def upload_image(
    inspection_id: str,
    surface_type: str = Form("FRONT"),
    file: UploadFile = File(...),
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if ins.get("status") == "FINALIZED":
        raise HTTPException(status_code=400, detail="Cannot add images to finalized inspection")

    file_bytes = await file.read()
    orig_path, thumb_path, width, height, sha256 = await storage_manager.save_inspection_image(
        inspection_id, file_bytes, file.filename or "surface.jpg"
    )

    # Perform CV Image Quality Assessment
    quality_info = cv_service.assess_image_quality(orig_path)

    image_record = {
        "id": f"img-{uuid.uuid4().hex[:8]}",
        "inspection_id": inspection_id,
        "surface_type": surface_type.upper(),
        "original_path": orig_path,
        "thumbnail_path": thumb_path,
        "width": width,
        "height": height,
        "mime_type": file.content_type or "image/jpeg",
        "file_size": len(file_bytes),
        "quality_score": quality_info["quality_score"],
        "quality_assessment": quality_info["assessment"],
        "quality_details": quality_info
    }

    saved_img = await repo.add_image(inspection_id, image_record)

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "IMAGE_UPLOADED",
        "resource_type": "INSPECTION_IMAGE",
        "resource_id": saved_img["id"],
        "metadata": {"surface": surface_type, "sha256": sha256}
    })

    return saved_img

@router.delete("/{inspection_id}/images/{image_id}")
async def delete_image(
    inspection_id: str,
    image_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins or ins.get("status") == "FINALIZED":
        raise HTTPException(status_code=400, detail="Inspection finalized or not found")
    deleted = await repo.delete_image(inspection_id, image_id)
    return {"success": deleted}

@router.post("/{inspection_id}/analyze", response_model=Dict[str, Any])
async def analyze_product(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    """
    Full AI-Assisted Pipeline:
    1. OCR extraction on captured images
    2. LLM semantic normalization referencing OCR block IDs
    3. Declaration Correctness & Cross-Field Consistency evaluation
    4. Versioned Rule Engine & Rule 7 Table-I PDP threshold resolution
    5. Computer Vision readability & placement analysis
    6. Deterministic Compliance Engine assessment
    """
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")

    images = ins.get("images", [])
    if not images:
        # Create a default fallback image representation for demo flow if none uploaded yet
        images = [{
            "id": f"img-{inspection_id}-front",
            "surface_type": "FRONT",
            "original_path": "storage/inspections/demo/rice_front.jpg"
        }]

    # Update status
    await repo.update(inspection_id, {"status": "ANALYSING"})

    # Step 1: OCR
    ocr_service = get_ocr_service()
    ocr_results = await ocr_service.extract_text_from_images(images)

    # Step 2: LLM Normalization
    llm_service = get_llm_service()
    extracted_payload = await llm_service.extract_declarations(ocr_results, product_category="Packaged Food")

    # Step 3: Declaration Correctness & Consistency
    all_ocr_blocks = []
    for r in ocr_results:
        all_ocr_blocks.extend(r.blocks)
    
    correctness_data = declaration_correctness_service.evaluate_correctness(
        extracted_payload, all_ocr_blocks, is_imported=False
    )

    # Step 4: Map declarations to database records
    declarations_records = []
    matrix = correctness_data.get("matrix", [])
    for idx, item in enumerate(matrix):
        field_name = item["field_name"]
        val = item.get("value")
        declarations_records.append({
            "id": f"dec-{inspection_id}-{idx + 1}",
            "inspection_id": inspection_id,
            "field_name": field_name,
            "ai_value": val,
            "verified_value": val,
            "unit": item.get("canonical_unit"),
            "confidence": item.get("confidence", 0.95),
            "source_image_id": images[0]["id"] if images else None,
            "source_block_id": item.get("source_block_id"),
            "source_text": val,
            "bbox": {"x": 100, "y": 200 + (idx * 60), "width": 400, "height": 45},
            "presence_status": "DETECTED" if item.get("presence") else "MISSING",
            "correctness_status": item.get("correctness", "VALID"),
            "verification_status": "PENDING",
            "provenance": "AI_EXTRACTED"
        })

    await repo.save_declarations(inspection_id, declarations_records)

    # Step 5: Rule & Compliance Engine
    rule_context = {
        "inspectionDate": ins.get("inspection_date") or get_utc_now_iso(),
        "productCategory": "Packaged Food",
        "isImported": False,
        "isEcommerce": ins.get("inspection_type") == "ONLINE_LISTING",
        "packageType": ins.get("package_type") or "RECTANGULAR",
        "packageConstructionType": ins.get("package_construction_type") or "NORMAL",
        "calibrationStatus": ins.get("calibration_status") or "NOT_CALIBRATED",
        "pdpAreaCm2": ins.get("pdp_data", {}).get("areaCm2", 320.0) if ins.get("pdp_data") else 320.0
    }

    compliance_assessment = await compliance_engine.evaluate_compliance(
        extracted_declarations=extracted_payload.model_dump(),
        correctness_data=correctness_data,
        context=rule_context
    )

    # Convert checks and violations to records
    check_records = []
    for idx, c in enumerate(compliance_assessment.checks):
        check_records.append({
            "id": f"chk-{inspection_id}-{idx + 1}",
            "inspection_id": inspection_id,
            "check_type": c.check_type,
            "field_name": c.field_name,
            "rule_code": c.rule_code,
            "rule_version": c.rule_version,
            "input_value": c.input_value,
            "expected_condition": c.expected_condition,
            "result": c.result,
            "confidence": c.confidence,
            "explanation": c.explanation,
            "source_reference": c.source_reference
        })

    violation_records = []
    for idx, v in enumerate(compliance_assessment.potential_violations):
        violation_records.append({
            "id": f"viol-{inspection_id}-{idx + 1}",
            "inspection_id": inspection_id,
            "type": v["type"],
            "severity": v.get("severity", "HIGH"),
            "confidence": v.get("confidence", 0.95),
            "status": "AI_DETECTED",
            "provenance": "AI_DETECTED",
            "ai_explanation": v.get("explanation"),
            "inspector_comment": None
        })

    await repo.save_compliance_results(inspection_id, check_records, violation_records)

    # Update inspection status & score
    final_status = "NEEDS_REVIEW" if (compliance_assessment.review_count > 0 or compliance_assessment.violation_count > 0) else "READY"
    await repo.update(inspection_id, {
        "status": final_status,
        "score": compliance_assessment.score,
        "applied_rule_version": "2024.1"
    })

    return {
        "success": True,
        "status": final_status,
        "score": compliance_assessment.score,
        "assessment": compliance_assessment.model_dump(),
        "declarations": declarations_records,
        "correctness_matrix": matrix
    }

@router.post("/{inspection_id}/finalize", response_model=Dict[str, Any])
async def finalize_inspection(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if ins.get("status") == "FINALIZED":
        return {"message": "Inspection already finalized", "inspection": ins}

    # Seal immutable snapshot
    snapshot_data = {
        "inspection_code": ins.get("inspection_code"),
        "finalized_at": get_utc_now_iso(),
        "finalized_by": user_payload["sub"],
        "officer_name": user_payload.get("full_name", "Officer"),
        "applied_rule_versions": ["RULE-006:v2024.1", "RULE-007:v2024.1", "RULE-009:v2024.1"],
        "score": ins.get("score"),
        "status": ins.get("status")
    }

    finalized = await repo.finalize_inspection(inspection_id, snapshot_data)

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "INSPECTION_FINALIZED",
        "resource_type": "INSPECTION",
        "resource_id": inspection_id,
        "old_value": {"status": ins.get("status")},
        "new_value": {"status": "FINALIZED"}
    })

    return {"success": True, "inspection": finalized}
