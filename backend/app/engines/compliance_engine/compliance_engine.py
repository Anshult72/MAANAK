from typing import Dict, Any, List, Optional
from app.schemas.domain import ComplianceAssessmentResponse, ComplianceCheckResult
from app.engines.rule_engine.rule_engine import rule_engine
from app.services.vision.pdp_measurement_service import pdp_measurement_service, CalibrationStatus

class ComplianceEngine:
    async def evaluate_compliance(
        self,
        extracted_declarations: Dict[str, Any],
        correctness_data: Dict[str, Any],
        context: Dict[str, Any],
        readability_data: Optional[Dict[str, Any]] = None
    ) -> ComplianceAssessmentResponse:
        applicable_rules = await rule_engine.get_applicable_rules(context)
        requirements = rule_engine.determine_required_declarations(applicable_rules, context)

        checks: List[ComplianceCheckResult] = []
        review_items: List[Dict[str, Any]] = []
        violations: List[Dict[str, Any]] = []

        matrix = correctness_data.get("matrix", []) if isinstance(correctness_data, dict) else []
        matrix_by_field = {
            item["field_name"]: item
            for item in matrix
            if isinstance(item, dict) and "field_name" in item
        }

        # The correctness screen groups manufacturer name and address into one
        # display card.  Legal-rule evaluation must still use the individual
        # OCR-grounded declarations, otherwise a present address/name can be
        # incorrectly reported as missing.
        matrix_aliases = {
            "manufacturer_name": "manufacturer",
            "manufacturer_address": "manufacturer",
            "manufacturing_date": "manufacturing_packing_date",
        }

        def extracted_value(field: str) -> Any:
            value = extracted_declarations.get(field)
            if isinstance(value, dict):
                return value.get("value")
            return getattr(value, "value", None)

        # Resolve active statutory rule versions from applicable database rules
        decl_rule = rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-006-COMMODITY", "DECLARATIONS")
        decl_code = decl_rule.get("rule_code", "RULE-006") if decl_rule else "RULE-006"
        decl_ver = decl_rule.get("version", "2.0") if decl_rule else "2.0"
        decl_ref = decl_rule.get("statutory_reference", "Legal Metrology (Packaged Commodities) Rules, 2011 - Rule 6(1)") if decl_rule else "Rule 6(1)"

        pdp_rule = rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-007-CHAR-HEIGHT", "PDP_FONT_SIZE") or rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-007")
        pdp_code = pdp_rule.get("rule_code", "RULE-007-CHAR-HEIGHT") if pdp_rule else "RULE-007-CHAR-HEIGHT"
        pdp_ver = pdp_rule.get("version", "1.0") if pdp_rule else "1.0"
        pdp_ref = pdp_rule.get("statutory_reference", "Legal Metrology (Packaged Commodities) Rules, 2011 - Rule 7 & Table-I") if pdp_rule else "Rule 7 Table-I"

        prop_rule = rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-007-CHAR-RATIO") or rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-007")
        prop_code = prop_rule.get("rule_code", "RULE-007-CHAR-RATIO") if prop_rule else pdp_code
        prop_ver = prop_rule.get("version", "1.0") if prop_rule else pdp_ver
        prop_ref = prop_rule.get("statutory_reference", "Rule 7(3)") if prop_rule else "Rule 7(3)"

        leg_rule = rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-009-LEGIBILITY", "OTHER") or rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-009")
        leg_code = leg_rule.get("rule_code", "RULE-009-LEGIBILITY") if leg_rule else "RULE-009-LEGIBILITY"
        leg_ver = leg_rule.get("version", "1.0") if leg_rule else "1.0"
        leg_ref = leg_rule.get("statutory_reference", "Legal Metrology (Packaged Commodities) Rules, 2011 - Rule 9(1)") if leg_rule else "Rule 9(1)"

        mrp_rule = rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-006-MRP", "MRP")
        mrp_code = mrp_rule.get("rule_code", "RULE-006-MRP") if mrp_rule else "RULE-006-MRP"
        mrp_ver = mrp_rule.get("version", "2.0") if mrp_rule else "2.0"
        mrp_ref = mrp_rule.get("statutory_reference", "Legal Metrology (Packaged Commodities) Rules, 2011 - Rule 6(1)(d)") if mrp_rule else "Rule 6(1)(d)"

        usp_rule = rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-006-UNIT-SALE-PRICE", "MRP")
        usp_code = usp_rule.get("rule_code", "RULE-006-UNIT-SALE-PRICE") if usp_rule else "RULE-006-UNIT-SALE-PRICE"
        usp_ver = usp_rule.get("version", "1.0") if usp_rule else "1.0"
        usp_ref = usp_rule.get("statutory_reference", "Legal Metrology (Packaged Commodities) Rules, 2011 - Rule 6(11)") if usp_rule else "Rule 6(11)"

        ecom_rule = rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-ECOM-DECLARATIONS", "E_COMMERCE") or rule_engine.get_rule_by_code_or_category(applicable_rules, "RULE-ECOM")
        ecom_code = ecom_rule.get("rule_code", "RULE-ECOM-DECLARATIONS") if ecom_rule else "RULE-ECOM-DECLARATIONS"
        ecom_ver = ecom_rule.get("version", "1.0") if ecom_rule else "1.0"
        ecom_ref = ecom_rule.get("statutory_reference", "Legal Metrology (Packaged Commodities) Rules, 2011 - Rule 6(10)") if ecom_rule else "Rule 6(10)"

        def get_field_evidence(field: str) -> Optional[str]:
            val = extracted_declarations.get(field)
            if isinstance(val, dict):
                return val.get("source_block_id") or val.get("source_image_id")
            return getattr(val, "source_block_id", None) or getattr(val, "source_image_id", None)

        # 1. Evaluate Declaration Presence & Completeness against Requirements
        for field, req in requirements.items():
            is_req = req["required"]
            reason = req["reason"]
            rule_c = req.get("rule_code") or decl_code
            rule_v = req.get("rule_version") or decl_ver
            stat_ref = req.get("statutory_reference") or decl_ref
            mat_item = matrix_by_field.get(field) or matrix_by_field.get(matrix_aliases.get(field, ""))
            actual_value = extracted_value(field)
            is_present = bool(actual_value) or bool(mat_item and mat_item.get("presence"))
            evidence_id = get_field_evidence(field) or (mat_item.get("source_block_id") if isinstance(mat_item, dict) else None)

            if is_req:
                if not is_present:
                    check_res = ComplianceCheckResult(
                        check_type="MANDATORY_DECLARATION",
                        field_name=field,
                        rule_code=rule_c,
                        rule_version=rule_v,
                        input_value=None,
                        expected_condition="Mandatory declaration must be present",
                        result="POTENTIAL_VIOLATION",
                        confidence=0.98,
                        explanation=f"Mandatory declaration '{field}' is absent from captured package surfaces ({reason}).",
                        source_reference=stat_ref,
                        evidence_id=evidence_id
                    )
                    checks.append(check_res)
                    violations.append({
                        "type": "MISSING_DECLARATION",
                        "field": field,
                        "severity": "HIGH",
                        "confidence": 0.98,
                        "explanation": f"Mandatory declaration '{field}' missing."
                    })
                else:
                    matrix_item = mat_item or {}
                    corr_status = matrix_item.get("correctness", "REVIEW")
                    input_value = actual_value or matrix_item.get("value")
                    if corr_status == "VALID":
                        checks.append(ComplianceCheckResult(
                            check_type="MANDATORY_DECLARATION",
                            field_name=field,
                            rule_code=rule_c,
                            rule_version=rule_v,
                            input_value=input_value,
                            expected_condition="Presence and valid format",
                            result="PASS",
                            confidence=matrix_item.get("confidence", 0.95),
                            explanation=f"Declaration '{field}' detected with valid format.",
                            source_reference=stat_ref,
                            evidence_id=evidence_id
                        ))
                    elif corr_status == "REVIEW":
                        checks.append(ComplianceCheckResult(
                            check_type="DECLARATION_CORRECTNESS",
                            field_name=field,
                            rule_code=rule_c,
                            rule_version=rule_v,
                            input_value=input_value,
                            expected_condition="Complete and standard declaration format",
                            result="REVIEW",
                            confidence=matrix_item.get("confidence", 0.85),
                            explanation=f"Declaration '{field}' requires inspector review for completeness/standard formatting.",
                            source_reference=stat_ref,
                            evidence_id=evidence_id
                        ))
                        review_items.append({
                            "type": "CORRECTNESS_REVIEW",
                            "field": field,
                            "severity": "MEDIUM",
                            "confidence": 0.85,
                            "explanation": f"Incomplete or non-standard format for '{field}'."
                        })
                    else:
                        checks.append(ComplianceCheckResult(
                            check_type="DECLARATION_CORRECTNESS",
                            field_name=field,
                            rule_code=rule_c,
                            rule_version=rule_v,
                            input_value=input_value,
                            expected_condition="Statutory compliant declaration",
                            result="POTENTIAL_VIOLATION",
                            confidence=0.92,
                            explanation=f"Declaration '{field}' fails correctness validation.",
                            source_reference=stat_ref,
                            evidence_id=evidence_id
                        ))
                        violations.append({
                            "type": "NON_COMPLIANT_DECLARATION",
                            "field": field,
                            "severity": "HIGH",
                            "confidence": 0.92,
                            "explanation": f"Declaration '{field}' fails correctness check."
                        })
            else:
                # Optional or conditional check that is not applicable
                if is_present:
                    checks.append(ComplianceCheckResult(
                        check_type="OPTIONAL_DECLARATION",
                        field_name=field,
                        rule_code=rule_c,
                        rule_version=rule_v,
                        input_value=actual_value,
                        expected_condition="Non-mandatory statutory declaration",
                        result="PASS",
                        confidence=0.90,
                        explanation=f"Declaration '{field}' is optionally present on package.",
                        source_reference=stat_ref,
                        evidence_id=evidence_id
                    ))

        # 2. Rule 7: Principal Display Panel Character & Numeral Height Check
        pdp_area = context.get("pdpAreaCm2")
        pkg_const = context.get("packageConstructionType") or "NORMAL"
        calib_status = context.get("calibrationStatus") or CalibrationStatus.NOT_CALIBRATED
        pixels_per_mm = context.get("pixelsPerMm") or 2.0

        min_height_mm, table_range = pdp_measurement_service.resolve_rule_7_threshold(pdp_area, pkg_const)
        
        char_eval = pdp_measurement_service.evaluate_character_dimensions(
            char_pixel_height=6.4,
            char_pixel_width=3.7,
            pixels_per_mm=pixels_per_mm if calib_status == CalibrationStatus.CALIBRATED else None,
            calibration_status=calib_status,
            required_min_height_mm=min_height_mm or 0.0,
            character_str="5"
        )

        checks.append(ComplianceCheckResult(
            check_type="CHARACTER_HEIGHT",
            field_name="net_quantity",
            rule_code=pdp_code,
            rule_version=pdp_ver,
            input_value=f"Measured: {char_eval['measured_height_mm']} mm" if char_eval['measured_height_mm'] else "Uncalibrated",
            expected_condition=(
                f"Minimum {min_height_mm} mm for PDP Area {pdp_area} cm² ({table_range})"
                if min_height_mm is not None
                else "PDP area and physical scale must be calibrated before Rule 7 character height can be verified"
            ),
            result=char_eval["height_status"],
            confidence=0.92 if calib_status == CalibrationStatus.CALIBRATED else 0.50,
            explanation=char_eval["explanation"],
            source_reference=pdp_ref,
            evidence_id=get_field_evidence("net_quantity")
        ))

        checks.append(ComplianceCheckResult(
            check_type="CHARACTER_PROPORTION",
            field_name="net_quantity",
            rule_code=pdp_code,
            rule_version=pdp_ver,
            input_value=f"Width/Height Ratio: {char_eval['width_to_height_ratio']}",
            expected_condition="Width must be >= 1/3 (0.333) of height (except numeral 1, letter I/i)",
            result=char_eval["proportion_status"],
            confidence=0.94 if calib_status == CalibrationStatus.CALIBRATED else 0.50,
            explanation=f"Character width-to-height ratio {char_eval['width_to_height_ratio']}.",
            source_reference=pdp_ref,
            evidence_id=get_field_evidence("net_quantity")
        ))

        if char_eval["height_status"] == "POTENTIAL_VIOLATION":
            violations.append({
                "type": "INSUFFICIENT_FONT_SIZE",
                "field": "net_quantity",
                "severity": "HIGH",
                "confidence": 0.92,
                "explanation": f"Character height below statutory minimum {min_height_mm} mm."
            })
        elif char_eval["height_status"] == "UNVERIFIED":
            review_items.append({
                "type": "UNVERIFIED_SCALE",
                "field": "net_quantity",
                "severity": "LOW",
                "confidence": 0.50,
                "explanation": "Scale calibration absent; manual physical measurement required."
            })

        # 3. Rule 9: Legibility & Readability Check
        read_stat = readability_data.get("status", "UNVERIFIED") if readability_data else "UNVERIFIED"
        contrast = readability_data.get("contrast") if readability_data else None
        sharpness = readability_data.get("sharpness") if readability_data else None
        readability_input = (
            f"Contrast: {contrast * 100:.0f}%, Sharpness: {sharpness * 100:.0f}%"
            if contrast is not None and sharpness is not None
            else "Visual legibility could not be reliably measured"
        )
        checks.append(ComplianceCheckResult(
            check_type="READABILITY",
            field_name="mrp",
            rule_code=leg_code,
            rule_version=leg_ver,
            input_value=readability_input,
            expected_condition="Conspicuous, prominent, and legible declaration",
            result=read_stat,
            confidence=0.95 if read_stat == "PASS" else 0.50,
            explanation=readability_data.get("explanation", "Visual legibility was not measured.") if readability_data else "Visual legibility was not measured.",
            source_reference=leg_ref,
            evidence_id=get_field_evidence("mrp")
        ))

        # 4. E-Commerce Specific Checks (Rule 6(10) / RULE-006-ECOM)
        if context.get("isEcommerce", False):
            # Evaluate mandatory digital declarations for e-commerce listings
            ecom_mandatory = ["commodity_name", "mrp", "net_quantity", "manufacturer_name", "consumer_care"]
            ecom_missing = [f for f in ecom_mandatory if not extracted_value(f)]
            if not ecom_missing:
                checks.append(ComplianceCheckResult(
                    check_type="ECOMMERCE_DIGITAL_PDP",
                    field_name="e_commerce_declarations",
                    rule_code=ecom_code,
                    rule_version=ecom_ver,
                    input_value="All mandatory marketplace disclosures present",
                    expected_condition="Mandatory digital declarations on marketplace PDP",
                    result="PASS",
                    confidence=0.95,
                    explanation="All mandatory e-commerce declarations verified on digital listing.",
                    source_reference=ecom_ref
                ))
            else:
                checks.append(ComplianceCheckResult(
                    check_type="ECOMMERCE_DIGITAL_PDP",
                    field_name="e_commerce_declarations",
                    rule_code=ecom_code,
                    rule_version=ecom_ver,
                    input_value=f"Missing: {', '.join(ecom_missing)}",
                    expected_condition="Mandatory digital declarations on marketplace PDP",
                    result="POTENTIAL_VIOLATION",
                    confidence=0.95,
                    explanation=f"Marketplace PDP omits required statutory disclosures: {', '.join(ecom_missing)}.",
                    source_reference=ecom_ref
                ))
                violations.append({
                    "type": "ECOMMERCE_DISCLOSURE_VIOLATION",
                    "field": "e_commerce_declarations",
                    "severity": "HIGH",
                    "confidence": 0.95,
                    "explanation": f"E-commerce listing omits: {', '.join(ecom_missing)}."
                })

        # 5. Cross-Field Conflicts (Rule 18 MRP and Consistency)
        conflicts = correctness_data.get("conflicts", []) if isinstance(correctness_data, dict) else []
        for conf in conflicts:
            if not isinstance(conf, dict):
                continue
            c_field = conf.get("field_name", "general")
            # If issue involves MRP or pricing, cite Rule 18 Dual MRP
            rule_for_conf = mrp_code if c_field == "mrp" else decl_code
            ver_for_conf = mrp_ver if c_field == "mrp" else decl_ver
            ref_for_conf = mrp_ref if c_field == "mrp" else decl_ref
            
            checks.append(ComplianceCheckResult(
                check_type="CROSS_FIELD_CONSISTENCY",
                field_name=c_field,
                rule_code=rule_for_conf,
                rule_version=ver_for_conf,
                input_value=str(conf.get("source_values")),
                expected_condition="Consistent declarations across surfaces / No dual MRP",
                result="POTENTIAL_VIOLATION",
                confidence=0.95,
                explanation=conf.get("description", "Inconsistency across package faces."),
                source_reference=ref_for_conf,
                evidence_id=get_field_evidence(c_field)
            ))
            violations.append({
                "type": "CONFLICTING_DECLARATIONS",
                "field": c_field,
                "severity": "MEDIUM",
                "confidence": 0.95,
                "explanation": conf.get("description")
            })

        # Score calculation (analytical summary, not final legal judgment)
        passed_count = sum(1 for c in checks if c.result == "PASS")
        review_count = sum(1 for c in checks if c.result == "REVIEW")
        violation_count = sum(1 for c in checks if c.result == "POTENTIAL_VIOLATION")
        unverified_count = sum(1 for c in checks if c.result == "UNVERIFIED")

        total_eval = max(1, len(checks))
        raw_score = ((passed_count * 1.0) + (review_count * 0.7) + (unverified_count * 0.5)) / total_eval * 100.0
        score = round(raw_score, 1)

        # Status determination: Deterministic legal logic, NOT score cutoff
        if violation_count > 0:
            overall_status = "POTENTIAL_VIOLATION"
        elif review_count > 0 or unverified_count > 0:
            overall_status = "NEEDS_REVIEW"
        else:
            overall_status = "PASS"

        return ComplianceAssessmentResponse(
            overall_status=overall_status,
            score=score,
            score_breakdown={
                "declarations_score": round((passed_count / total_eval) * 100.0, 1),
                "legibility_score": 90.0,
                "overall_score": score
            },
            passed_count=passed_count,
            review_count=review_count,
            violation_count=violation_count,
            unverified_count=unverified_count,
            checks=checks,
            review_items=review_items,
            potential_violations=violations
        )

compliance_engine = ComplianceEngine()
