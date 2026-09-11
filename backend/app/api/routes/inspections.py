import base64
import os
import uuid
from datetime import datetime, timezone
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, status
from fastapi.responses import FileResponse, Response
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
from app.core.config import settings
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
        if settings.is_demo_mode:
            logger.info("Reopening finalized inspection %s for demo modification", inspection_id)
            await repo.update(inspection_id, {"status": "DRAFT", "finalized_at": None})
        else:
            raise HTTPException(status_code=400, detail="Cannot modify a finalized inspection. Please select an in-progress case or create a new case.")

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
        if settings.is_demo_mode:
            logger.info("Reopening finalized inspection %s for demo image upload", inspection_id)
            await repo.update(inspection_id, {"status": "DRAFT", "finalized_at": None})
        else:
            raise HTTPException(
                status_code=400,
                detail="Cannot add images to a finalized inspection. Please select an in-progress case or create a new case."
            )

    file_bytes = await file.read()
    orig_path, thumb_path, width, height, sha256 = await storage_manager.save_inspection_image(
        inspection_id, file_bytes, file.filename or "surface.jpg"
    )

    # Perform CV Image Quality Assessment
    quality_info = cv_service.assess_image_quality(orig_path)

    # Persist image bytes as base64 in the quality_details JSON so images
    # survive Railway's ephemeral filesystem restarts without needing a
    # schema migration or external object storage.
    quality_info["_image_b64"] = base64.b64encode(file_bytes).decode("ascii")

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

@router.get("/{inspection_id}/images/{image_id}")
async def get_inspection_image(
    inspection_id: str,
    image_id: str,
):
    """Retrieve raw image file for an inspection.
    Attempts local disk read, and gracefully falls back to recovering image bytes
    from quality_details base64 storage if running on an ephemeral Railway container."""
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")

    images = ins.get("images", [])
    target = next((img for img in images if img.get("id") == image_id), None)
    if not target:
        raise HTTPException(status_code=404, detail="Image not found")

    orig_path = target.get("original_path")
    mime = target.get("mime_type") or "image/jpeg"

    if orig_path and os.path.isfile(orig_path):
        return FileResponse(orig_path, media_type=mime)

    # Ephemeral Railway fallback: restore from quality_details base64
    quality_details = target.get("quality_details") or {}
    b64_data = quality_details.get("_image_b64")
    if b64_data:
        try:
            raw_bytes = base64.b64decode(b64_data)
            return Response(content=raw_bytes, media_type=mime)
        except Exception:
            logger.warning("Failed to decode base64 image data for %s", image_id)

    raise HTTPException(status_code=404, detail="Image content unavailable")

@router.delete("/{inspection_id}/images/{image_id}")
async def delete_image(
    inspection_id: str,
    image_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")
    if ins.get("status") == "FINALIZED":
        if settings.is_demo_mode:
            await repo.update(inspection_id, {"status": "DRAFT", "finalized_at": None})
        else:
            raise HTTPException(status_code=400, detail="Cannot delete images from a finalized inspection")
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
        raise HTTPException(status_code=400, detail="Capture at least one package image before analysis.")

    # ── Restore missing image files from database-persisted base64 ──
    # Railway (like Render) uses an ephemeral filesystem; uploaded images
    # vanish on redeploy.  Re-materialise them from the base64 payload
    # stored in quality_details at upload time.
    for img_record in images:
        orig = img_record.get("original_path")
        if orig and not os.path.isfile(orig):
            qd = img_record.get("quality_details") or {}
            b64_data = qd.get("_image_b64")
            if b64_data:
                try:
                    os.makedirs(os.path.dirname(orig), exist_ok=True)
                    with open(orig, "wb") as f:
                        f.write(base64.b64decode(b64_data))
                    logger.info("Restored missing image from DB: %s", orig)
                except Exception as restore_err:
                    logger.warning("Could not restore image %s: %s", orig, restore_err)

    # Update status — any failure below must reset to DRAFT so the case is not stuck.
    await repo.update(inspection_id, {"status": "ANALYSING"})

    try:
        # Step 1: OCR extraction
        ocr_service = get_ocr_service()
        try:
            ocr_results = await ocr_service.extract_text_from_images(images)
        except FileNotFoundError as exc:
            logger.warning("Image file missing for %s: %s", inspection_id, exc)
            raise HTTPException(
                status_code=400,
                detail=(
                    "Captured package images are no longer available in server storage. "
                    "Please re-capture or re-upload the package photos."
                ),
            ) from exc
        except RuntimeError as exc:
            err_msg = str(exc).lower()
            if "no longer available" in err_msg or "storage" in err_msg:
                logger.warning("Image storage error for %s: %s", inspection_id, exc)
                raise HTTPException(
                    status_code=400,
                    detail=(
                        "Captured package images are no longer available in server storage. "
                        "Please re-capture or re-upload the package photos."
                    ),
                ) from exc
            logger.warning("OCR service error for %s: %s", inspection_id, exc)
            raise HTTPException(status_code=503, detail=str(exc)) from exc

        # Step 2: LLM Normalization
        llm_service = get_llm_service()
        extracted_payload = await llm_service.extract_declarations(ocr_results, product_category="Packaged Food")

        # Step 3: Declaration Correctness & Consistency
        all_ocr_blocks = []
        for r in ocr_results:
            all_ocr_blocks.extend(r.blocks)

        if not all_ocr_blocks:
            raise HTTPException(
                status_code=400,
                detail="No readable text detected on the package images. Please capture a clear, well-lit photo of the label declarations."
            )

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
                "source_image_id": item.get("source_image_id"),
                "source_block_id": item.get("source_block_id"),
                "source_text": item.get("source_text"),
                "bbox": item.get("bbox"),
                "presence_status": "DETECTED" if item.get("presence") else "MISSING",
                "correctness_status": item.get("correctness", "VALID"),
                "verification_status": "PENDING",
                "provenance": "AI_EXTRACTED"
            })

        await repo.save_declarations(inspection_id, declarations_records)

        # Step 5: Rule & Compliance Engine
        pdp_info = ins.get("pdp_data")
        rule_context = {
            "inspectionDate": ins.get("inspection_date") or get_utc_now_iso(),
            "productCategory": "Packaged Food",
            "isImported": False,
            "isEcommerce": ins.get("inspection_type") == "ONLINE_LISTING",
            "packageType": ins.get("package_type") or "RECTANGULAR",
            "packageConstructionType": ins.get("package_construction_type") or "NORMAL",
            "calibrationStatus": ins.get("calibration_status") or "NOT_CALIBRATED",
            "pdpAreaCm2": pdp_info.get("areaCm2") if isinstance(pdp_info, dict) else None
        }

        # This is measured from the captured photo; no default quality values are
        # used when the image cannot be analysed.
        first_img_path = images[0].get("original_path") if isinstance(images[0], dict) else None
        readability_data = cv_service.evaluate_readability(first_img_path)

        compliance_assessment = await compliance_engine.evaluate_compliance(
            extracted_declarations=extracted_payload.model_dump(),
            correctness_data=correctness_data,
            context=rule_context,
            readability_data=readability_data,
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
            if isinstance(v, dict):
                v_type = v.get("type", "UNKNOWN")
                v_sev = v.get("severity", "HIGH")
                v_conf = v.get("confidence", 0.95)
                v_exp = v.get("explanation") or v.get("ai_explanation")
            else:
                v_type = str(v)
                v_sev = "HIGH"
                v_conf = 0.95
                v_exp = str(v)
            violation_records.append({
                "id": f"viol-{inspection_id}-{idx + 1}",
                "inspection_id": inspection_id,
                "type": v_type,
                "severity": v_sev,
                "confidence": v_conf,
                "status": "AI_DETECTED",
                "provenance": "AI_DETECTED",
                "ai_explanation": v_exp,
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
    except HTTPException:
        await repo.update(inspection_id, {"status": "DRAFT"})
        raise
    except Exception as exc:
        logger.exception("Analysis failed for inspection %s", inspection_id)
        await repo.update(inspection_id, {"status": "DRAFT"})
        raise HTTPException(status_code=500, detail=f"Analysis failed: {exc}") from exc

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
