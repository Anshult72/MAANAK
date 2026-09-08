import hashlib
from typing import Dict, Any, Optional, Tuple
from app.repositories import get_repository

class ProductFingerprintService:
    @staticmethod
    def generate_product_identity_fingerprint(product_data: Dict[str, Any]) -> Tuple[str, str]:
        """
        Generates canonical text representation and deterministic SHA-256 hash.
        Includes ONLY persistent product attributes (brand, name, manufacturer, category, quantity, barcode).
        Excludes volatile fields like MRP, promotional claims, and dates!
        """
        brand = (product_data.get("brand") or "").strip().lower()
        name = (product_data.get("name") or "").strip().lower()
        mfg = (product_data.get("manufacturer_name") or "").strip().lower()
        category = (product_data.get("category") or "").strip().lower()
        qty = (product_data.get("net_quantity") or "").strip().lower()
        unit = (product_data.get("net_quantity_unit") or "").strip().upper()
        barcode = (product_data.get("barcode") or "").strip()

        canonical = f"brand:{brand}|name:{name}|mfg:{mfg}|cat:{category}|qty:{qty}{unit}|barcode:{barcode}"
        sha256 = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
        return sha256, canonical

    @staticmethod
    def generate_label_version_fingerprint(image_path: str, mrp: str, ocr_summary: str) -> str:
        """
        Generates label version fingerprint combining text and pricing.
        """
        combined = f"mrp:{mrp}|summary:{ocr_summary}"
        return hashlib.sha256(combined.encode("utf-8")).hexdigest()

    async def match_existing_product(self, product_data: Dict[str, Any]) -> Tuple[bool, Optional[str], float]:
        """
        Matches product against repository using canonical fingerprint or barcode.
        Returns: (is_matched, existing_product_id, match_confidence)
        """
        repo = get_repository()
        sha256, _ = self.generate_product_identity_fingerprint(product_data)
        barcode = product_data.get("barcode")

        # 1. Exact canonical fingerprint match
        matched_prod = await repo.get_by_fingerprint(sha256)
        if matched_prod:
            return True, matched_prod["id"], 0.98

        # 2. Barcode match
        if barcode:
            all_prods = await repo.list_products()
            for p in all_prods:
                if p.get("barcode") == barcode:
                    return True, p["id"], 0.95

        return False, None, 0.0

fingerprint_service = ProductFingerprintService()
