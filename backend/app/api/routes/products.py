from fastapi import APIRouter, Depends, HTTPException
from typing import Dict, Any, List
from app.repositories import get_repository
from app.core.security import get_current_user_payload
from app.services.label_change.label_change_service import label_change_service
from app.services.fingerprint.fingerprint_service import fingerprint_service

router = APIRouter(prefix="/api/products", tags=["Products & Fingerprints"])

@router.get("", response_model=List[Dict[str, Any]])
async def list_products(user_payload: dict = Depends(get_current_user_payload)):
    repo = get_repository()
    return await repo.list_products()

@router.get("/{product_id}", response_model=Dict[str, Any])
async def get_product(product_id: str, user_payload: dict = Depends(get_current_user_payload)):
    repo = get_repository()
    p = await repo.get_by_id(product_id)
    if not p:
        raise HTTPException(status_code=404, detail="Product not found")
    return p

@router.get("/{product_id}/history")
async def get_product_history(product_id: str, user_payload: dict = Depends(get_current_user_payload)):
    repo = get_repository()
    p = await repo.get_by_id(product_id)
    if not p:
        raise HTTPException(status_code=404, detail="Product not found")
    label_versions = await repo.get_label_versions(product_id)
    return {
        "product": p,
        "label_versions": label_versions,
        "inspection_count": len(label_versions) + 2
    }

@router.post("/{product_id}/label-compare")
async def compare_label_versions(
    product_id: str,
    req: Dict[str, Any],
    user_payload: dict = Depends(get_current_user_payload)
):
    current_mrp = req.get("current_mrp", "₹449")
    current_qty = req.get("current_quantity", "5 KG")
    summary = req.get("ocr_summary", "Updated packaging 2026")

    comparison = await label_change_service.compare_with_previous_version(
        product_id=product_id,
        current_mrp=current_mrp,
        current_quantity=current_qty,
        current_ocr_summary=summary
    )
    return comparison.model_dump()
