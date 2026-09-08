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

@router.post("/{inspection_id}/docx")
async def generate_and_archive_docx(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")

    existing_rep = await repo.get_report_by_inspection_id(inspection_id)
    version = (existing_rep.get("report_version", 1)) if existing_rep else 1

    # Construct shared InspectionReportModel
    report_model = InspectionReportModel(
        report_id=f"rep-{inspection_id}",
        report_version=version,
        inspection_id=inspection_id,
        inspection_code=ins.get("inspection_code", f"INS-{inspection_id[:6]}"),
        inspection_date=ins.get("inspection_date", get_utc_now_iso()),
        inspector_name=user_payload.get("full_name", "Legal Metrology Inspector"),
        officer_id=user_payload.get("officer_id", "LM-OFFICER"),
        location=ins.get("location", "Inspection Site"),
        seller_name=ins.get("seller_name"),
        business_name=ins.get("business_name"),
        inspection_type=ins.get("inspection_type", "PHYSICAL"),
        product_name="ABC Premium Basmati Rice",
        brand="ABC Heritage",
        category="Packaged Food",
        mrp="₹450.00",
        net_quantity="5 kg",
        overall_status=ins.get("status", "READY"),
        score=ins.get("score") or 90.0,
        pdp_area_cm2=ins.get("pdp_data", {}).get("areaCm2", 320.0),
        package_construction=ins.get("package_construction_type", "NORMAL"),
        calibration_status=ins.get("calibration_status", "CALIBRATED"),
        declarations=ins.get("declarations", []),
        compliance_checks=ins.get("checks", []),
        findings=ins.get("violations", []),
        evidence_images=[],
        inspector_remarks=ins.get("notes"),
        disclaimer="This document represents an AI-assisted inspection assessment generated from the captured evidence and configured compliance rules. It is intended to assist authorized personnel. Final regulatory determination and enforcement action remain with the competent authority/authorized officer.",
        generated_at=get_utc_now_iso()
    )

    docx_bytes = docx_report_generator.generate_docx(report_model)
    file_path, sha256 = await storage_manager.save_report_docx(inspection_id, docx_bytes, version)

    report_record = existing_rep or {
        "id": f"rep-{inspection_id}",
        "inspection_id": inspection_id,
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
    rep = await repo.get_report_by_inspection_id(inspection_id)
    if not rep or not rep.get("docx_path") or not os.path.exists(rep["docx_path"]):
        raise HTTPException(status_code=404, detail="DOCX report not found. Please trigger generation first.")

    return FileResponse(
        rep["docx_path"],
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        filename=os.path.basename(rep["docx_path"])
    )
