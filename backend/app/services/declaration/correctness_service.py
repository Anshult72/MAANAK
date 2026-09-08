import re
from typing import List, Dict, Any, Optional
from app.services.declaration.unit_validation import unit_validation_service
from app.services.declaration.cross_field_consistency import cross_field_consistency_service
from app.schemas.domain import CorrectnessCheckItem, ExtractedDeclarationsPayload, SemanticDeclarationField

def _safe_field(field: Optional[SemanticDeclarationField], name: str) -> SemanticDeclarationField:
    if field is not None:
        return field
    return SemanticDeclarationField(field_name=name, value=None, confidence=0.0)

class IDeclarationCorrectnessService:
    def evaluate_correctness(
        self,
        extracted: ExtractedDeclarationsPayload,
        ocr_blocks: List[Any],
        is_imported: bool = False
    ) -> Dict[str, Any]:
        pass

class DeclarationCorrectnessService(IDeclarationCorrectnessService):
    def evaluate_correctness(
        self,
        extracted: ExtractedDeclarationsPayload,
        ocr_blocks: List[Any],
        is_imported: bool = False
    ) -> Dict[str, Any]:
        matrix = []
        checks = []

        # --- 1. MRP CORRECTNESS ---
        mrp_field = _safe_field(extracted.mrp, "mrp")
        mrp_presence = "DETECTED" if mrp_field.value else "MISSING"
        mrp_correct = "VALID"
        mrp_details = "Valid currency and parseable price."

        if mrp_field.value:
            raw_str = mrp_field.value.strip()
            if "-" in raw_str:
                mrp_correct = "INVALID"
                mrp_details = "MRP cannot be negative."
            else:
                try:
                    match = re.search(r"(\d+(?:\.\d{1,2})?)", raw_str)
                    if not match:
                        mrp_correct = "REVIEW"
                        mrp_details = "No numeric price found."
                    else:
                        numeric_val = float(match.group(1))
                        if numeric_val <= 0:
                            mrp_correct = "INVALID"
                            mrp_details = "MRP must be a positive monetary value."
                except Exception:
                    mrp_correct = "REVIEW"
                    mrp_details = "Could not cleanly parse numeric price from string."
        else:
            mrp_correct = "NOT_APPLICABLE"
            mrp_details = "Field missing from captured surfaces."

        matrix.append({
            "declaration": "MRP / Retail Sale Price",
            "field_name": "mrp",
            "presence": mrp_presence == "DETECTED",
            "correctness": mrp_correct,
            "confidence": mrp_field.confidence,
            "value": mrp_field.value,
            "source_block_id": mrp_field.source_block_id,
            "final_check": "PASS" if mrp_presence == "DETECTED" and mrp_correct == "VALID" else ("REVIEW" if mrp_correct == "REVIEW" else "POTENTIAL_VIOLATION")
        })

        # --- 2. NET QUANTITY CORRECTNESS ---
        qty_field = _safe_field(extracted.net_quantity, "net_quantity")
        qty_presence = "DETECTED" if qty_field.value else "MISSING"
        qty_correct = "VALID"
        qty_details = "Valid numeric quantity and canonical unit."

        if qty_field.value:
            num_val, unit_val, is_valid_unit = unit_validation_service.parse_quantity(qty_field.value)
            if not is_valid_unit:
                qty_correct = "REVIEW"
                qty_details = f"Unit '{qty_field.unit}' is non-standard or missing. Legal Metrology standard units required (e.g. g, kg, ml, l)."
            elif num_val is None or num_val <= 0:
                qty_correct = "INVALID"
                qty_details = "Net quantity must be a positive numeric value."
        else:
            qty_correct = "NOT_APPLICABLE"
            qty_details = "Net quantity declaration is missing."

        matrix.append({
            "declaration": "Net Quantity",
            "field_name": "net_quantity",
            "presence": qty_presence == "DETECTED",
            "correctness": qty_correct,
            "confidence": qty_field.confidence,
            "value": qty_field.value,
            "canonical_unit": qty_field.canonical_unit,
            "source_block_id": qty_field.source_block_id,
            "final_check": "PASS" if qty_presence == "DETECTED" and qty_correct == "VALID" else ("REVIEW" if qty_correct == "REVIEW" else "POTENTIAL_VIOLATION")
        })

        # --- 3. MANUFACTURER SEPARATE NAME & ADDRESS ---
        mfg_name = _safe_field(extracted.manufacturer_name, "manufacturer_name")
        mfg_addr = _safe_field(extracted.manufacturer_address, "manufacturer_address")
        mfg_pres = "DETECTED" if (mfg_name.value or mfg_addr.value) else "MISSING"
        mfg_corr = "VALID"
        
        if mfg_pres == "DETECTED":
            has_name = bool(mfg_name.value and len(mfg_name.value.strip()) > 3)
            has_addr = bool(mfg_addr.value and len(mfg_addr.value.strip()) > 5)
            # Address completeness indicator (presence of postal/PIN or state or city)
            has_pin = bool(mfg_addr.value and re.search(r"\b\d{6}\b", mfg_addr.value))
            if has_name and has_addr and has_pin:
                mfg_corr = "VALID"
            elif has_name and has_addr:
                mfg_corr = "REVIEW"  # Incomplete postal code
            else:
                mfg_corr = "REVIEW"
        else:
            mfg_corr = "NOT_APPLICABLE"

        matrix.append({
            "declaration": "Manufacturer Name & Address",
            "field_name": "manufacturer",
            "presence": mfg_pres == "DETECTED",
            "correctness": mfg_corr,
            "confidence": mfg_name.confidence or 0.85,
            "value": f"{mfg_name.value or ''} - {mfg_addr.value or ''}".strip(" -"),
            "source_block_id": mfg_name.source_block_id,
            "final_check": "PASS" if mfg_pres == "DETECTED" and mfg_corr == "VALID" else "REVIEW"
        })

        # --- 4. IMPORTER NAME & ADDRESS (IF IMPORTED) ---
        if is_imported:
            imp_name = _safe_field(extracted.importer_name, "importer_name")
            imp_addr = _safe_field(extracted.importer_address, "importer_address")
            imp_pres = "DETECTED" if (imp_name.value or imp_addr.value) else "MISSING"
            imp_corr = "VALID" if (imp_name.value and imp_addr.value) else "REVIEW"

            matrix.append({
                "declaration": "Importer Name & Address",
                "field_name": "importer",
                "presence": imp_pres == "DETECTED",
                "correctness": imp_corr,
                "confidence": imp_name.confidence or 0.80,
                "value": f"{imp_name.value or ''} - {imp_addr.value or ''}".strip(" -"),
                "source_block_id": imp_name.source_block_id,
                "final_check": "PASS" if imp_pres == "DETECTED" and imp_corr == "VALID" else "POTENTIAL_VIOLATION"
            })

        # --- 5. DATES CORRECTNESS ---
        mfg_date = _safe_field(extracted.manufacturing_date, "manufacturing_date")
        pkg_date = _safe_field(extracted.packing_date, "packing_date")
        date_val = mfg_date.value or pkg_date.value
        date_pres = "DETECTED" if date_val else "MISSING"
        # Must match a strict calendar date format like MM/YYYY, MM-YYYY, YYYY-MM, DD/MM/YYYY
        is_strict_date_format = bool(date_val and re.match(r"^\s*(?:\d{1,2}[/-])?\d{1,2}[/-]\d{2,4}\s*$", date_val))
        date_corr = "VALID" if is_strict_date_format else "REVIEW"

        matrix.append({
            "declaration": "Date of Manufacture / Packing",
            "field_name": "manufacturing_packing_date",
            "presence": date_pres == "DETECTED",
            "correctness": date_corr,
            "confidence": mfg_date.confidence or pkg_date.confidence or 0.90,
            "value": date_val,
            "source_block_id": mfg_date.source_block_id or pkg_date.source_block_id,
            "final_check": "PASS" if date_pres == "DETECTED" and date_corr == "VALID" else "POTENTIAL_VIOLATION"
        })

        # --- 6. CONSUMER CARE ---
        cc_field = _safe_field(extracted.consumer_care, "consumer_care")
        cc_pres = "DETECTED" if cc_field.value else "MISSING"
        cc_corr = "VALID"
        if cc_field.value:
            has_phone = bool(re.search(r"\b(?:\d{3,4}[-\s]?\d{3,4}[-\s]?\d{3,4}|1800[-\s]?\d+)\b", cc_field.value))
            has_email = bool(re.search(r"[\w\.-]+@[\w\.-]+\.\w+", cc_field.value))
            if has_phone and has_email:
                cc_corr = "VALID"
            elif has_phone or has_email:
                cc_corr = "REVIEW"  # Only one channel available
            else:
                cc_corr = "REVIEW"
        else:
            cc_corr = "NOT_APPLICABLE"

        matrix.append({
            "declaration": "Consumer Care Details",
            "field_name": "consumer_care",
            "presence": cc_pres == "DETECTED",
            "correctness": cc_corr,
            "confidence": cc_field.confidence,
            "value": cc_field.value,
            "source_block_id": cc_field.source_block_id,
            "final_check": "PASS" if cc_pres == "DETECTED" and cc_corr == "VALID" else "REVIEW"
        })

        # --- 7. COUNTRY OF ORIGIN (CONDITIONAL ON IMPORTED) ---
        coo_field = _safe_field(extracted.country_of_origin, "country_of_origin")
        coo_pres = "DETECTED" if coo_field.value else "MISSING"
        coo_corr = "VALID" if coo_field.value and len(coo_field.value.strip()) >= 3 else "REVIEW"
        
        matrix.append({
            "declaration": "Country of Origin",
            "field_name": "country_of_origin",
            "presence": coo_pres == "DETECTED",
            "correctness": coo_corr,
            "confidence": coo_field.confidence,
            "value": coo_field.value,
            "source_block_id": coo_field.source_block_id,
            "final_check": "PASS" if coo_pres == "DETECTED" and coo_corr == "VALID" else ("REVIEW" if not is_imported else "POTENTIAL_VIOLATION")
        })

        # Detect cross-surface conflicts
        conflicts = cross_field_consistency_service.detect_conflicts(matrix, ocr_blocks)

        return {
            "matrix": matrix,
            "conflicts": [c.model_dump() for c in conflicts]
        }

declaration_correctness_service = DeclarationCorrectnessService()
