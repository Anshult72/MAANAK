from datetime import datetime, timezone
import uuid
from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any, List
from app.schemas.domain import FindingConfirmRequest, FindingRejectRequest, ManualFindingCreate
from app.repositories import get_repository
from app.core.security import get_current_user_payload

router = APIRouter(prefix="/api", tags=["Findings & Verification"])

def get_utc_now_iso():
    return datetime.now(timezone.utc).isoformat()

@router.get("/inspections/{inspection_id}/findings", response_model=List[Dict[str, Any]])
async def get_findings(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")
    return ins.get("violations", [])

@router.post("/findings/{finding_id}/confirm", response_model=Dict[str, Any])
async def confirm_finding(
    finding_id: str,
    req: FindingConfirmRequest,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    updates = {
        "status": "CONFIRMED",
        "provenance": "INSPECTOR_VERIFIED",
        "inspector_comment": req.inspector_comment or "Confirmed by inspector upon physical review.",
        "confirmed_by": user_payload["sub"],
        "confirmed_at": get_utc_now_iso()
    }
    updated = await repo.update_finding(finding_id, updates)
    if not updated:
        raise HTTPException(status_code=404, detail="Finding not found")

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "FINDING_CONFIRMED",
        "resource_type": "VIOLATION",
        "resource_id": finding_id,
        "metadata": {"comment": req.inspector_comment}
    })

    return updated

@router.post("/findings/{finding_id}/reject", response_model=Dict[str, Any])
async def reject_finding(
    finding_id: str,
    req: FindingRejectRequest,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    updates = {
        "status": "REJECTED",
        "provenance": "INSPECTOR_VERIFIED",
        "inspector_comment": req.inspector_comment or "Dismissed by inspector after physical verification.",
        "confirmed_by": user_payload["sub"],
        "confirmed_at": get_utc_now_iso()
    }
    updated = await repo.update_finding(finding_id, updates)
    if not updated:
        raise HTTPException(status_code=404, detail="Finding not found")

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "FINDING_REJECTED",
        "resource_type": "VIOLATION",
        "resource_id": finding_id,
        "metadata": {"comment": req.inspector_comment}
    })

    return updated

@router.post("/inspections/{inspection_id}/findings/manual", response_model=Dict[str, Any])
async def create_manual_finding(
    inspection_id: str,
    req: ManualFindingCreate,
    user_payload: dict = Depends(get_current_user_payload)
):
    """
    Allows inspector to record manual findings marked INSPECTOR_ADDED.
    """
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")

    finding_record = {
        "id": f"viol-man-{uuid.uuid4().hex[:8]}",
        "inspection_id": inspection_id,
        "type": req.type,
        "severity": req.severity,
        "confidence": 1.0,
        "status": "CONFIRMED",
        "provenance": "INSPECTOR_ADDED",
        "ai_explanation": f"Manual observation added by inspector: {req.title} - {req.description}",
        "inspector_comment": req.inspector_comment or req.description,
        "confirmed_by": user_payload["sub"],
        "confirmed_at": get_utc_now_iso()
    }

    current_viols = ins.get("violations", [])
    current_viols.append(finding_record)
    await repo.save_compliance_results(inspection_id, ins.get("checks", []), current_viols)

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "MANUAL_FINDING_ADDED",
        "resource_type": "VIOLATION",
        "resource_id": finding_record["id"],
        "metadata": {"title": req.title}
    })

    return finding_record
