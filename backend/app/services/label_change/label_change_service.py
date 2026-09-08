from typing import Dict, Any, List, Optional
from app.repositories import get_repository
from app.schemas.domain import LabelChangeComparisonResult

class LabelChangeService:
    async def compare_with_previous_version(
        self,
        product_id: str,
        current_mrp: str,
        current_quantity: str,
        current_ocr_summary: str
    ) -> LabelChangeComparisonResult:
        repo = get_repository()
        history = await repo.get_label_versions(product_id)
        if not history:
            return LabelChangeComparisonResult(
                has_significant_change=False,
                change_type="NO_SIGNIFICANT_CHANGE",
                diff_summary=["No previous label versions recorded for this product."],
                previous_label_version=None,
                current_label_version="v1.0",
                previous_mrp=None,
                current_mrp=current_mrp,
                visual_similarity=1.0
            )

        # Compare with most recent previous version
        prev = history[-1]
        diffs = []
        is_semantic_change = False
        is_visual_change = False

        prev_mrp = prev.get("mrp", "")
        if prev_mrp and current_mrp and prev_mrp.strip() != current_mrp.strip():
            diffs.append(f"MRP altered: {prev_mrp} → {current_mrp}")
            is_semantic_change = True

        prev_qty = prev.get("net_quantity", "")
        if prev_qty and current_quantity and prev_qty.strip().lower() != current_quantity.strip().lower():
            diffs.append(f"Net quantity changed: {prev_qty} → {current_quantity}")
            is_semantic_change = True

        # Text / layout differences
        if prev.get("ocr_summary") != current_ocr_summary:
            diffs.append("Package text and declaration formatting modified.")
            is_visual_change = True

        if is_semantic_change and is_visual_change:
            change_type = "BOTH"
        elif is_semantic_change:
            change_type = "SEMANTIC_CHANGE"
        elif is_visual_change:
            change_type = "VISUAL_CHANGE"
        else:
            change_type = "NO_SIGNIFICANT_CHANGE"

        has_change = is_semantic_change or is_visual_change

        return LabelChangeComparisonResult(
            has_significant_change=has_change,
            change_type=change_type,
            diff_summary=diffs if diffs else ["Identical label version and statutory declarations."],
            previous_label_version=prev.get("label_version", "v1.0"),
            current_label_version=f"v{len(history) + 1}.0",
            previous_mrp=prev_mrp,
            current_mrp=current_mrp,
            visual_similarity=0.82 if has_change else 1.0
        )

label_change_service = LabelChangeService()
