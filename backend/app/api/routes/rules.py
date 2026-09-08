from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any, List, Optional
from app.repositories import get_repository
from app.core.security import get_current_user_payload, require_role

router = APIRouter(prefix="/api/rules", tags=["Rule Administration"])

@router.get("", response_model=List[Dict[str, Any]])
async def list_rules(
    category: Optional[str] = None,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    return await repo.list_rules(category=category, active_only=False)

@router.get("/coverage", response_model=List[Dict[str, Any]])
async def get_rule_coverage(user_payload: dict = Depends(get_current_user_payload)):
    repo = get_repository()
    return await repo.get_rule_coverage()

@router.get("/{rule_id}", response_model=Dict[str, Any])
async def get_rule(rule_id: str, user_payload: dict = Depends(get_current_user_payload)):
    repo = get_repository()
    r = await repo.get_rule_by_id(rule_id)
    if not r:
        raise HTTPException(status_code=404, detail="Rule not found")
    return r

@router.post("", response_model=Dict[str, Any])
async def create_rule(
    rule_data: Dict[str, Any],
    user_payload: dict = Depends(require_role("ADMIN"))
):
    repo = get_repository()
    if not rule_data.get("code") or not rule_data.get("title"):
        raise HTTPException(status_code=400, detail="Rule code and title are mandatory.")
    
    created = await repo.create_rule(rule_data)

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "RULE_CREATED",
        "resource_type": "RULE",
        "resource_id": created["id"],
        "new_value": {"code": rule_data.get("code")}
    })

    return created

@router.post("/{rule_id}/versions", response_model=Dict[str, Any])
async def create_rule_version(
    rule_id: str,
    version_data: Dict[str, Any],
    user_payload: dict = Depends(require_role("ADMIN"))
):
    """
    Creates new immutable rule version preserving previous version history.
    """
    repo = get_repository()
    rule = await repo.get_rule_by_id(rule_id)
    if not rule:
        raise HTTPException(status_code=404, detail="Rule not found")

    if not version_data.get("version") or not version_data.get("effective_from"):
        raise HTTPException(status_code=400, detail="Version identifier and effective_from date are mandatory.")

    # Validate condition structure (controlled condition model)
    conditions = version_data.get("conditions", {})
    if not isinstance(conditions, dict) or "conditionGroup" not in conditions:
        raise HTTPException(status_code=400, detail="Invalid controlled condition model. Must contain 'conditionGroup' ('ALL', 'ANY', 'NOT').")

    created_version = await repo.create_version(rule_id, version_data)

    await repo.append_log({
        "user_id": user_payload["sub"],
        "role": user_payload["role"],
        "action": "RULE_VERSION_CREATED",
        "resource_type": "RULE_VERSION",
        "resource_id": created_version["id"],
        "new_value": {"rule_id": rule_id, "version": version_data.get("version")}
    })

    return created_version
