from fastapi import APIRouter, Depends
from typing import Dict, Any, List
from app.repositories import get_repository
from app.core.security import get_current_user_payload

router = APIRouter(prefix="/api/audit-logs", tags=["Audit Trail"])

@router.get("", response_model=List[Dict[str, Any]])
async def list_audit_logs(
    limit: int = 100,
    user_payload: dict = Depends(get_current_user_payload)
):
    repo = get_repository()
    return await repo.list_logs(limit=limit)
