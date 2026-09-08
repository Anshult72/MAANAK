import re
from typing import List, Dict, Any
from app.schemas.domain import CrossFieldConflictItem

class CrossFieldConsistencyService:
    @staticmethod
    def detect_conflicts(declarations: List[Dict[str, Any]], ocr_blocks: List[Any]) -> List[CrossFieldConflictItem]:
        conflicts = []

        # 1. Detect conflicting MRPs across surfaces
        mrp_numbers = []
        for blk in ocr_blocks:
            text = blk.text if hasattr(blk, "text") else blk.get("text", "")
            surface = blk.surface_type if hasattr(blk, "surface_type") else blk.get("surface_type", "FRONT")
            matches = re.findall(r"(?:MRP|Rs\.?|₹)\s*(\d+(?:\.\d{1,2})?)", text, re.IGNORECASE)
            for m in matches:
                try:
                    price = float(m)
                    if price > 0:
                        mrp_numbers.append({"surface": surface, "value": price, "text": text})
                except ValueError:
                    pass

        unique_prices = set(item["value"] for item in mrp_numbers)
        if len(unique_prices) > 1:
            conflicts.append(
                CrossFieldConflictItem(
                    field_name="mrp",
                    issue_type="MULTIPLE_MRPS",
                    description=f"Multiple conflicting retail prices detected across package surfaces: {[p['value'] for p in mrp_numbers]}",
                    source_values=mrp_numbers,
                    severity="POTENTIAL_ISSUE"
                )
            )

        # 2. Detect conflicting net quantities
        qty_values = []
        for blk in ocr_blocks:
            text = blk.text if hasattr(blk, "text") else blk.get("text", "")
            surface = blk.surface_type if hasattr(blk, "surface_type") else blk.get("surface_type", "FRONT")
            matches = re.findall(r"(?:Net\s*(?:Qty|Weight|Volume)?\s*:?\s*)(\d+(?:\.\d+)?)\s*(kg|g|ml|l)", text, re.IGNORECASE)
            for val, unit in matches:
                qty_values.append({"surface": surface, "value": f"{val} {unit.upper()}", "text": text})

        unique_qtys = set(item["value"] for item in qty_values)
        if len(unique_qtys) > 1:
            conflicts.append(
                CrossFieldConflictItem(
                    field_name="net_quantity",
                    issue_type="INCONSISTENT_QUANTITY",
                    description=f"Different net quantities observed across package faces: {list(unique_qtys)}",
                    source_values=qty_values,
                    severity="POTENTIAL_ISSUE"
                )
            )

        return conflicts

cross_field_consistency_service = CrossFieldConsistencyService()
