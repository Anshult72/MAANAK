import pytest
from app.services.fingerprint.fingerprint_service import fingerprint_service
from app.services.label_change.label_change_service import label_change_service

def test_product_identity_fingerprint_excludes_mrp():
    prod1 = {
        "brand": "ABC Heritage",
        "name": "ABC Premium Basmati Rice",
        "manufacturer_name": "ABC Agro Foods Ltd.",
        "category": "Packaged Food",
        "net_quantity": "5",
        "net_quantity_unit": "KG",
        "barcode": "8901234567890",
        "mrp": "₹399.00"
    }
    prod2 = {
        "brand": "ABC Heritage",
        "name": "ABC Premium Basmati Rice",
        "manufacturer_name": "ABC Agro Foods Ltd.",
        "category": "Packaged Food",
        "net_quantity": "5",
        "net_quantity_unit": "KG",
        "barcode": "8901234567890",
        "mrp": "₹449.00"  # Different MRP
    }
    hash1, repr1 = fingerprint_service.generate_product_identity_fingerprint(prod1)
    hash2, repr2 = fingerprint_service.generate_product_identity_fingerprint(prod2)

    # Hashes must be identical because MRP is a volatile field and not part of identity fingerprint!
    assert hash1 == hash2
    assert repr1 == repr2

@pytest.mark.asyncio
async def test_label_change_detection_mrp_alteration():
    # Test comparing against existing seed product 'prod-rice-01' which has previous MRP ₹449
    res = await label_change_service.compare_with_previous_version(
        product_id="prod-rice-01",
        current_mrp="₹499",
        current_quantity="5 KG",
        current_ocr_summary="Updated 2026 label text"
    )
    assert res.has_significant_change is True
    assert "MRP altered" in res.diff_summary[0]
    assert res.change_type in ["SEMANTIC_CHANGE", "BOTH"]
    assert res.previous_mrp is not None
