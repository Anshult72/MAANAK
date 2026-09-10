import os
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Response, status
from fastapi.responses import FileResponse
from typing import Dict, Any
from app.repositories import get_repository
from app.core.security import get_current_user_payload
from app.storage.file_storage import storage_manager
from app.services.reports.docx_generator import docx_report_generator
from app.schemas.domain import InspectionReportModel
from app.core.logging import logger

router = APIRouter(prefix="/api/reports", tags=["Reports"])

def get_utc_now_iso():
    return datetime.now(timezone.utc).isoformat()

@router.get("/{inspection_id}")
async def get_report_metadata(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    rep = await repo.get_report_by_inspection_id(inspection_id)
    if not rep:
        return {
            "inspection_id": inspection_id,
            "report_version": 1,
            "archival_status": "NOT_GENERATED"
        }
    return rep

@router.post("/{inspection_id}/pdf")
async def archive_pdf_report(
    inspection_id: str,
    file: UploadFile = File(...),
    user_payload: dict = Depends(get_current_user_payload)
):
    """
    Archives Flutter-generated dynamic A4 PDF report with SHA-256 integrity.
    """
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")

    file_bytes = await file.read()
    if len(file_bytes) > 20 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Report file size exceeds 20 MB limit.")

    existing_rep = await repo.get_report_by_inspection_id(inspection_id)
    version = (existing_rep.get("report_version", 0) + 1) if existing_rep else 1

    file_path, sha256 = await storage_manager.save_report_pdf(inspection_id, file_bytes, version)

    report_record = {
        "id": existing_rep.get("id") if existing_rep else f"rep-{inspection_id}",
        "inspection_id": inspection_id,
        "report_version": version,
        "pdf_path": file_path,
        "pdf_sha256": sha256,
        "pdf_generated_at": get_utc_now_iso(),
        "archival_status": "ARCHIVED",
        "generated_by": user_payload["sub"]
    }

    saved = await repo.save_report_metadata(report_record)

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "PDF_REPORT_ARCHIVED",
        "resource_type": "REPORT",
        "resource_id": saved["id"],
        "metadata": {"sha256": sha256, "version": version}
    })

    return {"success": True, "report": saved}

@router.get("/{inspection_id}/pdf")
async def get_pdf_report(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    rep = await repo.get_report_by_inspection_id(inspection_id)
    if not rep or not rep.get("pdf_path") or not os.path.exists(rep["pdf_path"]):
        raise HTTPException(status_code=404, detail="PDF report not found or not yet generated.")
    
    return FileResponse(
        rep["pdf_path"],
        media_type="application/pdf",
        filename=os.path.basename(rep["pdf_path"])
    )

def _build_report_model(ins: Dict[str, Any], user_payload: Dict[str, Any], version: int = 1) -> InspectionReportModel:
    declarations = ins.get("declarations", [])
    decl_map = {}
    formatted_declarations = []
    for d in declarations:
        if isinstance(d, dict):
            f_name = d.get("field_name", "")
            f_val = d.get("verified_value") or d.get("ai_value") or "N/A"
            decl_map[f_name] = f_val
            is_missing = d.get("presence_status") == "MISSING"
            is_invalid = d.get("correctness_status") == "INVALID"
            is_review = d.get("correctness_status") == "REVIEW"
            status_str = "FAIL" if (is_missing or is_invalid) else ("REVIEW" if is_review else "PASS")
            formatted_declarations.append({
                "declaration": f_name.replace("_", " ").title(),
                "ai_value": d.get("ai_value") or ("Missing" if is_missing else "N/A"),
                "verified_value": f_val,
                "correctness": d.get("correctness_status", "VALID"),
                "final_check": status_str
            })

    checks = ins.get("checks", [])
    formatted_checks = []
    for c in checks:
        if isinstance(c, dict):
            formatted_checks.append({
                "rule_code": c.get("rule_code", "RULE"),
                "check_type": c.get("check_type", "AUDIT"),
                "input_value": str(c.get("input_value", "")),
                "expected_condition": str(c.get("expected_condition", "")),
                "result": str(c.get("result", "PASS"))
            })

    pdp_info = ins.get("pdp_data") or {}
    pdp_area = pdp_info.get("areaCm2") or pdp_info.get("area_cm2") or 140.0

    return InspectionReportModel(
        report_id=f"rep-{ins.get('id', 'default')}",
        report_version=version,
        inspection_id=ins.get("id", ""),
        inspection_code=ins.get("inspection_code", f"INS-{str(ins.get('id', ''))[:6]}"),
        inspection_date=ins.get("inspection_date", get_utc_now_iso()),
        inspector_name=user_payload.get("full_name") or user_payload.get("sub") or "Legal Metrology Inspector",
        officer_id=user_payload.get("officer_id", "LM-OFFICER"),
        location=ins.get("location", "Inspection Site"),
        seller_name=ins.get("seller_name") or ins.get("business_name"),
        business_name=ins.get("business_name") or ins.get("seller_name"),
        inspection_type=ins.get("inspection_type", "PHYSICAL"),
        product_name=decl_map.get("commodity_name") or decl_map.get("product_name") or "Packaged Commodity",
        brand=decl_map.get("brand") or ins.get("business_name") or "Packaged Goods",
        category="Packaged Commodity",
        mrp=decl_map.get("mrp") or "N/A",
        net_quantity=decl_map.get("net_quantity") or "N/A",
        overall_status=ins.get("status", "READY"),
        score=ins.get("score") or 90.0,
        pdp_area_cm2=float(pdp_area) if pdp_area else 140.0,
        package_construction=ins.get("package_construction_type", "NORMAL"),
        calibration_status=ins.get("calibration_status", "CALIBRATED"),
        declarations=formatted_declarations,
        compliance_checks=formatted_checks,
        findings=ins.get("violations", []),
        evidence_images=[],
        inspector_remarks=ins.get("notes"),
        disclaimer="This document represents an AI-assisted inspection assessment generated from the captured evidence and configured compliance rules. It is intended to assist authorized personnel. Final regulatory determination and enforcement action remain with the competent authority/authorized officer.",
        generated_at=get_utc_now_iso()
    )

@router.post("/{inspection_id}/docx")
async def generate_and_archive_docx(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")

    canonical_id = ins.get("id", inspection_id)
    existing_rep = await repo.get_report_by_inspection_id(canonical_id)
    version = (existing_rep.get("report_version", 1)) if existing_rep else 1

    report_model = _build_report_model(ins, user_payload, version)
    docx_bytes = docx_report_generator.generate_docx(report_model)
    file_path, sha256 = await storage_manager.save_report_docx(canonical_id, docx_bytes, version)

    report_record = existing_rep or {
        "id": f"rep-{canonical_id}",
        "inspection_id": canonical_id,
        "report_version": version,
        "generated_by": user_payload["sub"]
    }
    report_record["docx_path"] = file_path
    report_record["docx_sha256"] = sha256
    report_record["docx_generated_at"] = get_utc_now_iso()

    saved = await repo.save_report_metadata(report_record)

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "DOCX_REPORT_GENERATED",
        "resource_type": "REPORT",
        "resource_id": saved["id"],
        "metadata": {"sha256": sha256, "version": version}
    })

    return {"success": True, "report": saved}

@router.get("/{inspection_id}/docx")
async def get_docx_report(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")

    canonical_id = ins.get("id", inspection_id)
    rep = await repo.get_report_by_inspection_id(canonical_id)
    if rep and rep.get("docx_path") and os.path.isfile(rep["docx_path"]):
        return FileResponse(
            rep["docx_path"],
            media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            filename=os.path.basename(rep["docx_path"])
        )

    # Dynamic on-demand generation: if file is not on disk or hasn't been pre-generated
    version = (rep.get("report_version", 1)) if rep else 1
    report_model = _build_report_model(ins, user_payload, version)
    docx_bytes = docx_report_generator.generate_docx(report_model)

    try:
        file_path, sha256 = await storage_manager.save_report_docx(canonical_id, docx_bytes, version)
        report_record = rep or {
            "id": f"rep-{canonical_id}",
            "inspection_id": canonical_id,
            "report_version": version,
            "generated_by": user_payload.get("sub", "system")
        }
        report_record["docx_path"] = file_path
        report_record["docx_sha256"] = sha256
        report_record["docx_generated_at"] = get_utc_now_iso()
        await repo.save_report_metadata(report_record)
    except Exception as e:
        logger.warning(f"Could not persist docx report to disk: {e}")

    filename = f"MAANAK_REPORT_{ins.get('inspection_code', canonical_id)}.docx"
    return Response(
        content=docx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"'
        }
    )
