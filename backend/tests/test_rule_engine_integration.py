import pytest
import pytest_asyncio
from app.repositories import get_repository
from app.engines.rule_engine.rule_engine import rule_engine
from app.engines.compliance_engine.compliance_engine import compliance_engine
from app.scripts.seed_legal_rules import seed_real_statutory_rules
from app.api.routes.rules import normalize_category_filter

@pytest.mark.asyncio
async def test_idempotent_seeding_and_active_rules():
    # 1. Test idempotent seed execution
    await seed_real_statutory_rules()
    await seed_real_statutory_rules()

    repo = get_repository()
    rules = await repo.list_rules()
    assert len(rules) >= 8

    # Verify key statutory rules exist
    rule_codes = {r["code"] for r in rules}
    assert "RULE-006-COMMODITY" in rule_codes
    assert "RULE-006-NET-QTY" in rule_codes
    assert "RULE-006-MRP" in rule_codes
    assert "RULE-006-NAME-ADDR" in rule_codes
    assert "RULE-006-DATES" in rule_codes
    assert "RULE-006-CONSUMER-CARE" in rule_codes
    assert "RULE-006-UNIT-SALE-PRICE" in rule_codes
    assert "RULE-007-PDP-AREA" in rule_codes
    assert "RULE-007-CHAR-HEIGHT" in rule_codes
    assert "RULE-007-CHAR-RATIO" in rule_codes
    assert "RULE-009-LEGIBILITY" in rule_codes
    assert "RULE-ECOM-DECLARATIONS" in rule_codes
    assert "RULE-ECOM-FUTURE-2027" in rule_codes

@pytest.mark.asyncio
async def test_effective_date_selection_for_current_vs_future():
    repo = get_repository()
    
    # 2026 inspection date: Should return active rules for 2026
    active_2026 = await repo.get_active_versions_for_date("2026-09-08T00:00:00Z")
    active_codes_2026 = {v["rule_code"] for v in active_2026}
    
    assert "RULE-006-COMMODITY" in active_codes_2026
    assert "RULE-007-CHAR-HEIGHT" in active_codes_2026
    # Future scheduled rule (effective 2027-07-01) must NOT be active in 2026
    assert "RULE-ECOM-FUTURE-2027" not in active_codes_2026

    # 2027 inspection date: Future scheduled rule becomes active
    active_2027 = await repo.get_active_versions_for_date("2027-08-01T00:00:00Z")
    active_codes_2027 = {v["rule_code"] for v in active_2027}
    assert "RULE-ECOM-FUTURE-2027" in active_codes_2027

@pytest.mark.asyncio
async def test_category_normalization():
    assert normalize_category_filter("ALL") is None
    assert normalize_category_filter("") is None
    assert normalize_category_filter("PDP / FONT SIZE") == "PDP_FONT_SIZE"
    assert normalize_category_filter("pdp_font_size") == "PDP_FONT_SIZE"
    assert normalize_category_filter("E-COMMERCE") == "E_COMMERCE"
    assert normalize_category_filter("DECLARATIONS") == "DECLARATIONS"
    assert normalize_category_filter("MRP") == "MRP"
    assert normalize_category_filter("OTHER") == "OTHER"

@pytest.mark.asyncio
async def test_compliance_engine_statutory_citations_and_evidence():
    context = {
        "inspectionDate": "2026-09-08T00:00:00Z",
        "isImported": False,
        "isEcommerce": False,
        "calibrationStatus": "NOT_CALIBRATED",
        "packageConstructionType": "NORMAL",
        "pdpAreaCm2": 150.0
    }

    # Declarations with commodity_name, net_quantity, mrp present
    extracted_declarations = {
        "commodity_name": {"value": "Organic Wheat Flour", "source_block_id": "blk-01"},
        "net_quantity": {"value": "1 kg", "source_block_id": "blk-02"},
        "mrp": {"value": "₹ 75.00", "source_block_id": "blk-03"},
        "manufacturer_name": {"value": "Bharat Agro Mills Ltd", "source_block_id": "blk-04"},
        "manufacturer_address": {"value": "Plot 12, Ind Area, New Delhi 110020", "source_block_id": "blk-05"},
        "manufacturing_date": {"value": "08/2026", "source_block_id": "blk-06"},
        "consumer_care": {"value": "customercare@bharatagro.in", "source_block_id": "blk-07"}
    }

    correctness_data = {
        "matrix": [
            {"field_name": "commodity_name", "presence": True, "correctness": "VALID", "confidence": 0.98},
            {"field_name": "net_quantity", "presence": True, "correctness": "VALID", "confidence": 0.99},
            {"field_name": "mrp", "presence": True, "correctness": "VALID", "confidence": 0.98},
            {"field_name": "manufacturer", "presence": True, "correctness": "VALID", "confidence": 0.95},
            {"field_name": "manufacturing_packing_date", "presence": True, "correctness": "VALID", "confidence": 0.96},
            {"field_name": "consumer_care", "presence": True, "correctness": "VALID", "confidence": 0.97},
        ],
        "conflicts": []
    }

    readability_data = {
        "status": "PASS",
        "contrast": 0.65,
        "sharpness": 0.55,
        "explanation": "High label contrast and sharp edges detected."
    }

    assessment = await compliance_engine.evaluate_compliance(
        extracted_declarations=extracted_declarations,
        correctness_data=correctness_data,
        context=context,
        readability_data=readability_data
    )

    assert assessment is not None
    assert len(assessment.checks) > 0

    # Verify checks contain statutory citations
    statutory_refs = {c.source_reference for c in assessment.checks}
    assert any("Rule 6" in ref for ref in statutory_refs)
    assert any("Rule 7" in ref for ref in statutory_refs)
    assert any("Rule 9" in ref for ref in statutory_refs)

    # Verify evidence_id is preserved on checks
    checks_with_evidence = [c for c in assessment.checks if c.evidence_id is not None]
    assert len(checks_with_evidence) > 0

@pytest.mark.asyncio
async def test_ecommerce_specific_compliance_check():
    context = {
        "inspectionDate": "2026-09-08T00:00:00Z",
        "isImported": False,
        "isEcommerce": True,
        "calibrationStatus": "NOT_CALIBRATED"
    }

    # E-commerce missing consumer care
    extracted_declarations = {
        "commodity_name": {"value": "Basmati Rice"},
        "mrp": {"value": "₹ 150.00"},
        "net_quantity": {"value": "1 kg"},
        "manufacturer_name": {"value": "Rice Co Ltd"},
    }

    assessment = await compliance_engine.evaluate_compliance(
        extracted_declarations=extracted_declarations,
        correctness_data={"matrix": [], "conflicts": []},
        context=context
    )

    ecom_checks = [c for c in assessment.checks if c.check_type == "ECOMMERCE_DIGITAL_PDP"]
    assert len(ecom_checks) == 1
    # Missing consumer_care should flag potential violation for e-commerce
    assert ecom_checks[0].result == "POTENTIAL_VIOLATION"
    assert "Rule 6(10)" in ecom_checks[0].source_reference
    assert ecom_checks[0].rule_code == "RULE-ECOM-DECLARATIONS"

@pytest.mark.asyncio
async def test_dual_mrp_conflict_cites_rule_18():
    context = {
        "inspectionDate": "2026-09-08T00:00:00Z",
        "isImported": False,
        "isEcommerce": False
    }

    extracted_declarations = {
        "mrp": {"value": "₹ 100.00"}
    }

    # Cross-field conflict with multiple MRPs
    correctness_data = {
        "matrix": [],
        "conflicts": [
            {
                "field_name": "mrp",
                "issue_type": "MULTIPLE_MRPS",
                "description": "Dual MRP detected: Front face declares Rs. 100, back face declares Rs. 120",
                "source_values": [{"face": "FRONT", "val": 100}, {"face": "BACK", "val": 120}]
            }
        ]
    }

    assessment = await compliance_engine.evaluate_compliance(
        extracted_declarations=extracted_declarations,
        correctness_data=correctness_data,
        context=context
    )

    conflict_checks = [c for c in assessment.checks if c.check_type == "CROSS_FIELD_CONSISTENCY"]
    assert len(conflict_checks) == 1
    assert "RULE-006-MRP" in conflict_checks[0].rule_code
    assert "Rule 6" in conflict_checks[0].source_reference or "Rule 18" in conflict_checks[0].source_reference
