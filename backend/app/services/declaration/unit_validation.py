import re
from typing import Optional, Tuple

class UnitValidationService:
    # Standard Legal Metrology units (Rules 11-13)
    MASS_UNITS = {"G": "G", "GM": "G", "GRAM": "G", "GRAMS": "G", "KG": "KG", "KILOGRAM": "KG", "किलोग्राम": "KG", "ग्राम": "G"}
    VOLUME_UNITS = {"ML": "ML", "MILLILITRE": "ML", "MILLILITER": "ML", "L": "L", "LT": "L", "LTR": "L", "LITRE": "L", "LITER": "L", "लीटर": "L", "मिली": "ML"}
    LENGTH_UNITS = {"MM": "MM", "MILLIMETRE": "MM", "CM": "CM", "CENTIMETRE": "CM", "M": "M", "METRE": "M"}
    COUNT_UNITS = {"N": "U", "U": "U", "UNIT": "U", "UNITS": "U", "PIECE": "U", "PCS": "U", "NUMBER": "U"}

    ALL_UNITS = {**MASS_UNITS, **VOLUME_UNITS, **LENGTH_UNITS, **COUNT_UNITS}

    @classmethod
    def normalize_unit(cls, unit_str: Optional[str]) -> Optional[str]:
        if not unit_str:
            return None
        cleaned = re.sub(r"[^a-zA-Z\u0900-\u097F]", "", unit_str.strip()).upper()
        return cls.ALL_UNITS.get(cleaned, None)

    @classmethod
    def parse_quantity(cls, qty_str: Optional[str]) -> Tuple[Optional[float], Optional[str], bool]:
        """
        Parses raw text such as '5 kg' or '200 ml' into (value, canonical_unit, is_valid)
        """
        if not qty_str:
            return None, None, False
        match = re.search(r"(\d+(?:\.\d+)?)\s*([a-zA-Z\u0900-\u097F]+)", qty_str)
        if not match:
            return None, None, False
        val = float(match.group(1))
        unit = cls.normalize_unit(match.group(2))
        return val, unit, unit is not None

unit_validation_service = UnitValidationService()
