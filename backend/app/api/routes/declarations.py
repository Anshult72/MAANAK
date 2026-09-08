from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any, List
from app.schemas.domain import DeclarationUpdate
from app.repositories import get_repository
from app.core.security import get_current_user_payload

router = APIRouter(prefix="/api", tags=["Declarations"])

@router.get("/inspections/{inspection_id}/declarations", response_model=List[Dict[str, Any]])
async def get_inspection_declarations(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")
    return ins.get("declarations", [])

@router.patch("/declarations/{declaration_id}", response_model=Dict[str, Any])
async def update_declaration(
    declaration_id: str,
    req: DeclarationUpdate,
    user_payload: dict = Depends(get_current_user_payload)
):
    """
    Inspector modifies verified_value while strictly preserving raw ai_value.
    """
    repo = get_repository()
    updates = {
        "verified_value": req.verified_value,
        "verification_status": "EDITED",
        "provenance": "INSPECTOR_VERIFIED",
        "verified_by": user_payload["sub"],
        "notes": req.notes
    }
    if req.unit:
        updates["unit"] = req.unit

    updated = await repo.update_declaration(declaration_id, updates)
    if not updated:
        raise HTTPException(status_code=404, detail="Declaration not found")

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "DECLARATION_EDITED",
        "resource_type": "DECLARATION",
        "resource_id": declaration_id,
        "new_value": updates
    })

    return updated

@router.get("/inspections/{inspection_id}/declaration-correctness")
async def get_declaration_correctness(
    inspection_id: str,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    ins = await repo.get_by_id(inspection_id)
    if not ins:
        raise HTTPException(status_code=404, detail="Inspection not found")
    return {
        "inspection_id": inspection_id,
        "declarations": ins.get("declarations", [])
    }
