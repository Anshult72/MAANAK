import pytest
from app.services.declaration.unit_validation import unit_validation_service
from app.services.declaration.cross_field_consistency import cross_field_consistency_service
from app.services.declaration.correctness_service import declaration_correctness_service
from app.schemas.domain import (
    ExtractedDeclarationsPayload, SemanticDeclarationField, OcrBlock, BoundingBox
)

def build_dummy_payload(
    mrp_val="₹450.00",
    qty_val="5 kg",
    qty_unit="KG",
    mfg_name="ABC Agro Foods Ltd.",
    mfg_addr="Plot 42, Food Industrial Estate, Karnal, Haryana - 132001",
    imp_name=None,
    imp_addr=None,
    mfg_date="08/2026",
    coo="India"
):
    return ExtractedDeclarationsPayload(
        commodity_name=SemanticDeclarationField(field_name="commodity_name", value="ABC Basmati Rice", confidence=0.99),
        net_quantity=SemanticDeclarationField(field_name="net_quantity", value=qty_val, unit=qty_unit, canonical_unit=qty_unit, confidence=0.98),
        mrp=SemanticDeclarationField(field_name="mrp", value=mrp_val, confidence=0.99),
        manufacturer_name=SemanticDeclarationField(field_name="manufacturer_name", value=mfg_name, confidence=0.96),
        manufacturer_address=SemanticDeclarationField(field_name="manufacturer_address", value=mfg_addr, confidence=0.95),
        packer_name=SemanticDeclarationField(field_name="packer_name", value=mfg_name, confidence=0.96),
        packer_address=SemanticDeclarationField(field_name="packer_address", value=mfg_addr, confidence=0.95),
        importer_name=SemanticDeclarationField(field_name="importer_name", value=imp_name, confidence=0.90 if imp_name else 0.0),
        importer_address=SemanticDeclarationField(field_name="importer_address", value=imp_addr, confidence=0.90 if imp_addr else 0.0),
        manufacturing_date=SemanticDeclarationField(field_name="manufacturing_date", value=mfg_date, confidence=0.98),
        packing_date=SemanticDeclarationField(field_name="packing_date", value=mfg_date, confidence=0.98),
        import_date=SemanticDeclarationField(field_name="import_date", value=None),
        expiry_date=SemanticDeclarationField(field_name="expiry_date", value=None),
        best_before=SemanticDeclarationField(field_name="best_before", value=None),
        use_by=SemanticDeclarationField(field_name="use_by", value=None),
        consumer_care=SemanticDeclarationField(field_name="consumer_care", value="1800-111-2222, care@abcagro.com", confidence=0.97),
        country_of_origin=SemanticDeclarationField(field_name="country_of_origin", value=coo, confidence=0.99),
        dimensions=SemanticDeclarationField(field_name="dimensions", value=None),
        unit_sale_price=SemanticDeclarationField(field_name="unit_sale_price", value=None),
        barcode=SemanticDeclarationField(field_name="barcode", value="8901234567890", confidence=0.99)
    )

# 1. Test Valid MRP
def test_valid_mrp():
    payload = build_dummy_payload(mrp_val="₹450.00")
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    mrp_item = next(i for i in res["matrix"] if i["field_name"] == "mrp")
    assert mrp_item["presence"] is True
    assert mrp_item["correctness"] == "VALID"
    assert mrp_item["final_check"] == "PASS"

# 2. Test Malformed MRP
def test_malformed_mrp():
    payload = build_dummy_payload(mrp_val="₹ -45.00")
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    mrp_item = next(i for i in res["matrix"] if i["field_name"] == "mrp")
    assert mrp_item["correctness"] in ["INVALID", "REVIEW"]

# 3. Test Conflicting MRP across surfaces
def test_conflicting_mrp():
    payload = build_dummy_payload(mrp_val="₹399.00")
    dummy_ocr_blocks = [
        OcrBlock(block_id="b1", text="MRP ₹ 399.00", confidence=0.99, bbox=BoundingBox(x=0, y=0, width=10, height=10), image_id="i1", surface_type="FRONT"),
        OcrBlock(block_id="b2", text="MRP ₹ 449.00", confidence=0.99, bbox=BoundingBox(x=0, y=0, width=10, height=10), image_id="i2", surface_type="BACK")
    ]
    res = declaration_correctness_service.evaluate_correctness(payload, dummy_ocr_blocks, is_imported=False)
    assert len(res["conflicts"]) > 0
    assert res["conflicts"][0]["issue_type"] == "MULTIPLE_MRPS"

# 4. Test Valid Net Quantity
def test_valid_net_quantity():
    payload = build_dummy_payload(qty_val="5 kg", qty_unit="KG")
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    qty_item = next(i for i in res["matrix"] if i["field_name"] == "net_quantity")
    assert qty_item["presence"] is True
    assert qty_item["correctness"] == "VALID"

# 5. Test Non-Standard Unit Normalization
def test_unit_normalization():
    norm1 = unit_validation_service.normalize_unit("kilogram")
    assert norm1 == "KG"
    norm2 = unit_validation_service.normalize_unit("किलोग्राम")
    assert norm2 == "KG"
    norm3 = unit_validation_service.normalize_unit("gm")
    assert norm3 == "G"
    norm4 = unit_validation_service.normalize_unit("ml")
    assert norm4 == "ML"
    norm_invalid = unit_validation_service.normalize_unit("bottles")
    assert norm_invalid is None

# 6. Test Ambiguous / Non-Legal Quantity Unit
def test_ambiguous_quantity():
    payload = build_dummy_payload(qty_val="5 packets", qty_unit="packets")
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    qty_item = next(i for i in res["matrix"] if i["field_name"] == "net_quantity")
    assert qty_item["correctness"] == "REVIEW"

# 7. Test Valid Date
def test_valid_date():
    payload = build_dummy_payload(mfg_date="08/2026")
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    date_item = next(i for i in res["matrix"] if i["field_name"] == "manufacturing_packing_date")
    assert date_item["presence"] is True
    assert date_item["correctness"] == "VALID"

# 8. Test Malformed Date
def test_malformed_date():
    payload = build_dummy_payload(mfg_date="Someday in 2026")
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    date_item = next(i for i in res["matrix"] if i["field_name"] == "manufacturing_packing_date")
    assert date_item["correctness"] == "REVIEW"

# 9. Test Separate Manufacturer vs Importer
def test_separate_mfg_importer_roles():
    payload = build_dummy_payload(
        mfg_name="Paris Fragrance Ltd.",
        mfg_addr="Paris, France",
        imp_name="Luxe Impex India",
        imp_addr="Plot 1, Mumbai - 400001"
    )
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=True)
    mfg_item = next(i for i in res["matrix"] if i["field_name"] == "manufacturer")
    imp_item = next(i for i in res["matrix"] if i["field_name"] == "importer")
    assert mfg_item["presence"] is True
    assert imp_item["presence"] is True
    assert imp_item["correctness"] == "VALID"

# 10. Test Missing Importer Address when Product is Imported
def test_missing_importer_address_when_imported():
    payload = build_dummy_payload(
        mfg_name="Paris Fragrance Ltd.",
        mfg_addr="Paris, France",
        imp_name="Luxe Impex India",
        imp_addr=None  # Missing address
    )
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=True)
    imp_item = next(i for i in res["matrix"] if i["field_name"] == "importer")
    assert imp_item["correctness"] == "REVIEW"
    assert imp_item["final_check"] == "POTENTIAL_VIOLATION"

# 11. Test Country of Origin Presence
def test_country_of_origin_presence():
    payload = build_dummy_payload(coo="India")
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    coo_item = next(i for i in res["matrix"] if i["field_name"] == "country_of_origin")
    assert coo_item["presence"] is True
    assert coo_item["correctness"] == "VALID"

# 12. Test Inconsistent Net Quantities Conflict Detection
def test_inconsistent_net_quantities():
    dummy_ocr_blocks = [
        OcrBlock(block_id="q1", text="Net Qty: 500 g", confidence=0.99, bbox=BoundingBox(x=0, y=0, width=10, height=10), image_id="i1", surface_type="FRONT"),
        OcrBlock(block_id="q2", text="Net Qty: 1 kg", confidence=0.99, bbox=BoundingBox(x=0, y=0, width=10, height=10), image_id="i2", surface_type="BACK")
    ]
    payload = build_dummy_payload()
    res = declaration_correctness_service.evaluate_correctness(payload, dummy_ocr_blocks, is_imported=False)
    qty_conflicts = [c for c in res["conflicts"] if c["field_name"] == "net_quantity"]
    assert len(qty_conflicts) > 0
    assert qty_conflicts[0]["issue_type"] == "INCONSISTENT_QUANTITY"

# 13. Test Incomplete Address Indicator
def test_incomplete_address_indicator():
    # Address without postal code or full address details
    payload = build_dummy_payload(mfg_addr="Industrial Area")
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    mfg_item = next(i for i in res["matrix"] if i["field_name"] == "manufacturer")
    assert mfg_item["correctness"] == "REVIEW"

# 14. Test Consumer Care Email Only (No Phone)
def test_consumer_care_partial_contact():
    payload = build_dummy_payload()
    payload.consumer_care.value = "care@abcagro.com"  # Email only
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    cc_item = next(i for i in res["matrix"] if i["field_name"] == "consumer_care")
    assert cc_item["correctness"] == "REVIEW"

# 15. Test Consumer Care Complete Phone and Email
def test_consumer_care_complete_contact():
    payload = build_dummy_payload()
    payload.consumer_care.value = "1800-111-2222 or email care@abcagro.com"
    res = declaration_correctness_service.evaluate_correctness(payload, [], is_imported=False)
    cc_item = next(i for i in res["matrix"] if i["field_name"] == "consumer_care")
    assert cc_item["correctness"] == "VALID"
