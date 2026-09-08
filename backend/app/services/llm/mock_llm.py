from typing import List, Optional
from app.services.llm.interface import ILlmService
from app.schemas.domain import (
    OcrResult, ExtractedDeclarationsPayload, SemanticDeclarationField, BoundingBox
)

class MockLlmService(ILlmService):
    async def extract_declarations(
        self,
        ocr_results: List[OcrResult],
        product_category: str = "Packaged Food"
    ) -> ExtractedDeclarationsPayload:
        # Build block lookup map
        all_blocks = []
        for r in ocr_results:
            all_blocks.extend(r.blocks)

        def find_block(keywords: List[str]):
            for b in all_blocks:
                text_lower = b.text.lower()
                if any(kw.lower() in text_lower for kw in keywords):
                    return b
            return None

        # 1. Commodity Name
        name_blk = find_block(["rice", "shampoo", "serum", "oil", "premium", "basmati"])
        commodity_name = SemanticDeclarationField(
            field_name="commodity_name",
            value=name_blk.text if name_blk else "ABC Premium Basmati Rice",
            normalized_value=name_blk.text if name_blk else "ABC Premium Basmati Rice",
            confidence=name_blk.confidence if name_blk else 0.98,
            source_block_id=name_blk.block_id if name_blk else "blk-01",
            source_image_id=name_blk.image_id if name_blk else None,
            source_text=name_blk.text if name_blk else "ABC Premium Basmati Rice",
            bbox=name_blk.bbox if name_blk else BoundingBox(x=120, y=180, width=640, height=75)
        )

        # 2. Net Quantity
        qty_blk = find_block(["net weight", "net qty", "5 kg", "200 ml", "50 ml", "1 l"])
        val_str = "5 kg"
        unit_str = "KG"
        if qty_blk:
            if "200" in qty_blk.text or "ml" in qty_blk.text.lower():
                val_str = "200 ml"
                unit_str = "ML"
            elif "50" in qty_blk.text:
                val_str = "50 ml"
                unit_str = "ML"
        net_quantity = SemanticDeclarationField(
            field_name="net_quantity",
            value=val_str,
            normalized_value="5" if unit_str == "KG" else ("200" if val_str == "200 ml" else "50"),
            unit=unit_str,
            canonical_unit=unit_str,
            confidence=qty_blk.confidence if qty_blk else 0.99,
            source_block_id=qty_blk.block_id if qty_blk else "blk-03",
            source_image_id=qty_blk.image_id if qty_blk else None,
            source_text=qty_blk.text if qty_blk else f"Net Qty: {val_str}",
            bbox=qty_blk.bbox if qty_blk else BoundingBox(x=140, y=850, width=280, height=55)
        )

        # 3. MRP
        mrp_blk = find_block(["mrp", "₹", "rs", "price"])
        mrp_val = "₹450.00"
        if mrp_blk and "240" in mrp_blk.text:
            mrp_val = "₹240.00"
        elif mrp_blk and "399" in mrp_blk.text:
            mrp_val = "₹399.00"
        mrp = SemanticDeclarationField(
            field_name="mrp",
            value=mrp_val,
            normalized_value="450.00" if "450" in mrp_val else ("240.00" if "240" in mrp_val else "399.00"),
            unit="INR",
            canonical_unit="INR",
            confidence=mrp_blk.confidence if mrp_blk else 0.99,
            source_block_id=mrp_blk.block_id if mrp_blk else "blk-10",
            source_image_id=mrp_blk.image_id if mrp_blk else None,
            source_text=mrp_blk.text if mrp_blk else f"MRP {mrp_val} (Incl. of all taxes)",
            bbox=mrp_blk.bbox if mrp_blk else BoundingBox(x=80, y=150, width=520, height=52)
        )

        # 4. Manufacturer separate name & address
        mfg_blk = find_block(["manufactured", "mfd by", "produced by", "laboratoires"])
        manufacturer_name = SemanticDeclarationField(
            field_name="manufacturer_name",
            value="ABC Agro Foods Ltd.",
            normalized_value="ABC Agro Foods Ltd.",
            confidence=mfg_blk.confidence if mfg_blk else 0.96,
            source_block_id=mfg_blk.block_id if mfg_blk else "blk-14",
            source_image_id=mfg_blk.image_id if mfg_blk else None,
            source_text=mfg_blk.text if mfg_blk else "Manufactured by: ABC Agro Foods Ltd.",
            bbox=mfg_blk.bbox if mfg_blk else BoundingBox(x=80, y=410, width=780, height=85)
        )
        manufacturer_address = SemanticDeclarationField(
            field_name="manufacturer_address",
            value="Plot 42, Food Industrial Estate, Karnal, Haryana - 132001",
            normalized_value="Plot 42, Food Industrial Estate, Karnal, Haryana - 132001",
            confidence=0.95,
            source_block_id=mfg_blk.block_id if mfg_blk else "blk-14",
            source_image_id=mfg_blk.image_id if mfg_blk else None,
            source_text=mfg_blk.text if mfg_blk else "Plot 42, Food Industrial Estate, Karnal, Haryana - 132001",
            bbox=mfg_blk.bbox if mfg_blk else BoundingBox(x=80, y=410, width=780, height=85)
        )

        # 5. Packer separate name & address
        packer_name = SemanticDeclarationField(
            field_name="packer_name",
            value="ABC Agro Foods Ltd.",
            normalized_value="ABC Agro Foods Ltd.",
            confidence=0.96,
            source_block_id=mfg_blk.block_id if mfg_blk else "blk-14",
            source_image_id=mfg_blk.image_id if mfg_blk else None,
            source_text=mfg_blk.text if mfg_blk else "Packed by: ABC Agro Foods Ltd.",
            bbox=mfg_blk.bbox if mfg_blk else BoundingBox(x=80, y=410, width=780, height=85)
        )
        packer_address = SemanticDeclarationField(
            field_name="packer_address",
            value="Plot 42, Food Industrial Estate, Karnal, Haryana - 132001",
            normalized_value="Plot 42, Food Industrial Estate, Karnal, Haryana - 132001",
            confidence=0.95,
            source_block_id=mfg_blk.block_id if mfg_blk else "blk-14",
            source_image_id=mfg_blk.image_id if mfg_blk else None,
            source_text=mfg_blk.text if mfg_blk else "Plot 42, Food Industrial Estate, Karnal, Haryana - 132001",
            bbox=mfg_blk.bbox if mfg_blk else BoundingBox(x=80, y=410, width=780, height=85)
        )

        # 6. Importer separate name & address (null for domestic)
        is_imported = "imported" in product_category.lower() or "paris" in (name_blk.text.lower() if name_blk else "")
        importer_name = SemanticDeclarationField(
            field_name="importer_name",
            value="Luxe India Cosmetics Impex Ltd." if is_imported else None,
            normalized_value="Luxe India Cosmetics Impex Ltd." if is_imported else None,
            confidence=0.92 if is_imported else 0.0,
            source_block_id="blk-imp-01" if is_imported else None,
            source_image_id=None,
            source_text="Imported by: Luxe India Cosmetics Impex Ltd." if is_imported else None,
            bbox=None
        )
        importer_address = SemanticDeclarationField(
            field_name="importer_address",
            value=None,  # Deliberate missing address for test case
            normalized_value=None,
            confidence=0.0,
            source_block_id=None,
            source_image_id=None,
            source_text=None,
            bbox=None
        )

        # 7. Dates separate semantic fields
        date_blk = find_block(["packed", "pkg", "mfd", "date", "08/2026"])
        manufacturing_date = SemanticDeclarationField(
            field_name="manufacturing_date",
            value="08/2026",
            normalized_value="2026-08",
            confidence=date_blk.confidence if date_blk else 0.98,
            source_block_id=date_blk.block_id if date_blk else "blk-12",
            source_image_id=date_blk.image_id if date_blk else None,
            source_text=date_blk.text if date_blk else "Packed on: 08/2026",
            bbox=date_blk.bbox if date_blk else BoundingBox(x=80, y=275, width=260, height=40)
        )
        packing_date = SemanticDeclarationField(
            field_name="packing_date",
            value="08/2026",
            normalized_value="2026-08",
            confidence=date_blk.confidence if date_blk else 0.98,
            source_block_id=date_blk.block_id if date_blk else "blk-12",
            source_image_id=date_blk.image_id if date_blk else None,
            source_text=date_blk.text if date_blk else "Packed on: 08/2026",
            bbox=date_blk.bbox if date_blk else BoundingBox(x=80, y=275, width=260, height=40)
        )
        import_date = SemanticDeclarationField(field_name="import_date", value=None, confidence=0.0)
        expiry_date = SemanticDeclarationField(field_name="expiry_date", value=None, confidence=0.0)

        bb_blk = find_block(["best before", "use by"])
        best_before = SemanticDeclarationField(
            field_name="best_before",
            value="24 months from packaging" if bb_blk else None,
            normalized_value="24 months" if bb_blk else None,
            confidence=bb_blk.confidence if bb_blk else 0.0,
            source_block_id=bb_blk.block_id if bb_blk else None,
            source_image_id=bb_blk.image_id if bb_blk else None,
            source_text=bb_blk.text if bb_blk else None,
            bbox=bb_blk.bbox if bb_blk else None
        )
        use_by = SemanticDeclarationField(field_name="use_by", value=None, confidence=0.0)

        # 8. Consumer Care
        cc_blk = find_block(["customer care", "consumer care", "care@", "1800-"])
        consumer_care = SemanticDeclarationField(
            field_name="consumer_care",
            value=cc_blk.text if cc_blk else "1800-111-2222 | care@abcagro.com",
            normalized_value="Phone: 1800-111-2222, Email: care@abcagro.com",
            confidence=cc_blk.confidence if cc_blk else 0.98,
            source_block_id=cc_blk.block_id if cc_blk else "blk-15",
            source_image_id=cc_blk.image_id if cc_blk else None,
            source_text=cc_blk.text if cc_blk else "Customer Care: 1800-111-2222 | care@abcagro.com",
            bbox=cc_blk.bbox if cc_blk else BoundingBox(x=80, y=520, width=560, height=48)
        )

        # 9. Country of origin
        coo_blk = find_block(["country of origin", "made in", "india", "france"])
        country_of_origin = SemanticDeclarationField(
            field_name="country_of_origin",
            value="India" if not is_imported else "France",
            normalized_value="India" if not is_imported else "France",
            confidence=coo_blk.confidence if coo_blk else 0.99,
            source_block_id=coo_blk.block_id if coo_blk else "blk-16",
            source_image_id=coo_blk.image_id if coo_blk else None,
            source_text=coo_blk.text if coo_blk else "Country of Origin: India",
            bbox=coo_blk.bbox if coo_blk else BoundingBox(x=80, y=585, width=320, height=44)
        )

        # 10. Dimensions & Unit Sale Price
        dimensions = SemanticDeclarationField(field_name="dimensions", value=None, confidence=0.0)
        
        usp_blk = find_block(["unit sale price", "usp"])
        unit_sale_price = SemanticDeclarationField(
            field_name="unit_sale_price",
            value="₹ 90.00 / kg" if usp_blk else None,
            normalized_value="90.00" if usp_blk else None,
            unit="INR/KG" if usp_blk else None,
            canonical_unit="INR/KG" if usp_blk else None,
            confidence=usp_blk.confidence if usp_blk else 0.0,
            source_block_id=usp_blk.block_id if usp_blk else None,
            source_image_id=usp_blk.image_id if usp_blk else None,
            source_text=usp_blk.text if usp_blk else None,
            bbox=usp_blk.bbox if usp_blk else None
        )

        # 11. Barcode
        bc_blk = find_block(["barcode", "890123", "890987", "360052"])
        barcode = SemanticDeclarationField(
            field_name="barcode",
            value=bc_blk.text if bc_blk else "8901234567890",
            normalized_value="8901234567890",
            confidence=bc_blk.confidence if bc_blk else 0.99,
            source_block_id=bc_blk.block_id if bc_blk else "blk-20",
            source_image_id=bc_blk.image_id if bc_blk else None,
            source_text=bc_blk.text if bc_blk else "Barcode: 8901234567890",
            bbox=bc_blk.bbox if bc_blk else BoundingBox(x=100, y=100, width=300, height=60)
        )

        return ExtractedDeclarationsPayload(
            commodity_name=commodity_name,
            net_quantity=net_quantity,
            mrp=mrp,
            manufacturer_name=manufacturer_name,
            manufacturer_address=manufacturer_address,
            packer_name=packer_name,
            packer_address=packer_address,
            importer_name=importer_name,
            importer_address=importer_address,
            manufacturing_date=manufacturing_date,
            packing_date=packing_date,
            import_date=import_date,
            expiry_date=expiry_date,
            best_before=best_before,
            use_by=use_by,
            consumer_care=consumer_care,
            country_of_origin=country_of_origin,
            dimensions=dimensions,
            unit_sale_price=unit_sale_price,
            barcode=barcode
        )
