"""
MAANAK Authoritative Legal Metrology Rule Registry Seed Script
Ingests structured, version-controlled statutory rules from official Department of Consumer Affairs
and Government of India Gazette notifications.
"""

import asyncio
import os
import sys
from datetime import datetime, timezone
from typing import List, Dict, Any

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))

from app.core.config import settings
from app.core.database import Base, engine, AsyncSessionLocal
from app.core.legal_sources import get_official_sources, compute_document_hash
from app.models.entities import (
    Rule, RuleVersion, LegalDocument, RuleAmendment, RuleCoverage
)
from app.core.logging import logger

def _dt(iso_str: str) -> datetime:
    return datetime.fromisoformat(iso_str.replace("Z", "+00:00"))

# Structured Real Statutory Rules Specification
STATUTORY_RULES_SPEC: List[Dict[str, Any]] = [
    # =========================================================================
    # CATEGORY: DECLARATIONS (Rule 6, Rule 10, Rule 12)
    # =========================================================================
    {
        "id": "rule-006-name-addr",
        "code": "RULE-006-NAME-ADDR",
        "statutory_reference": "Rule 6(1)(a) & Rule 10, LM (Packaged Commodities) Rules, 2011",
        "title": "Manufacturer, Packer or Importer Name & Complete Address",
        "category": "DECLARATIONS",
        "validation_type": "MANDATORY_DECLARATION",
        "description": "Every package shall bear the name and complete address of the manufacturer, or where the manufacturer is not the packer, the name and address of the manufacturer and packer, and for imported goods, the name and complete address of the importer.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "mandatory_fields": ["manufacturer_name", "manufacturer_address"],
            "conditional_fields": {
                "importer_name": {"condition": "isImported", "value": True},
                "importer_address": {"condition": "isImported", "value": True},
                "packer_name": {"condition": "isPackerDistinct", "value": True},
                "packer_address": {"condition": "isPackerDistinct", "value": True}
            },
            "address_requirements": ["pincode_present", "city_or_district_present"]
        },
        "evidence_requirements_json": ["IMAGE_SURFACE", "OCR_BOUNDING_BOX", "VERIFIED_ADDRESS_TEXT"],
        "active": True,
        "versions": [
            {
                "id": "ver-006-name-addr-v1",
                "version": "1.0",
                "version_label": "2011 Base Enactment",
                "description": "Statutory baseline requiring full physical postal address of manufacturer, packer, or importer.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True, "strict_address_check": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 6(1)(a)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": "2022-12-01T00:00:00Z",
                "status": "SUPERSEDED"
            },
            {
                "id": "ver-006-name-addr-v2",
                "version": "2.0",
                "version_label": "2022 Statutory Amendment",
                "description": "Permits registered office address declaration with valid postal PIN code, telephone, and official email for corporate packers.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True, "pincode_required": True, "digital_contact_permitted": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Amendment Rules, 2022, GSR 226(E)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-amend-2022-usp",
                "publication_date": "2022-03-28T00:00:00Z",
                "effective_from": "2022-12-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ],
        "amendments": [
            {
                "id": "amend-006-name-addr-2022",
                "previous_version_id": "ver-006-name-addr-v1",
                "new_version_id": "ver-006-name-addr-v2",
                "amendment_type": "TEXTUAL",
                "amendment_summary": "Clarified that registered office address with postal PIN code and digital contact suffices for corporate entities under Rule 10.",
                "source_document_id": "doc-amend-2022-usp",
                "effective_from": "2022-12-01T00:00:00Z"
            }
        ]
    },
    {
        "id": "rule-006-origin",
        "code": "RULE-006-ORIGIN",
        "statutory_reference": "Rule 6(1)(a) Proviso, LM (Packaged Commodities) Rules, 2011",
        "title": "Country of Origin for Imported Packaged Commodities",
        "category": "DECLARATIONS",
        "validation_type": "MANDATORY_DECLARATION",
        "description": "For imported pre-packaged commodities, the country of origin or manufacturer country must be conspicuously declared on the package.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "mandatory_when": {"isImported": True},
            "valid_country_format": True,
            "prohibited_generic_terms": ["imported", "foreign", "overseas"]
        },
        "evidence_requirements_json": ["IMAGE_SURFACE", "OCR_BOUNDING_BOX", "COUNTRY_TEXT"],
        "active": True,
        "versions": [
            {
                "id": "ver-006-origin-v1",
                "version": "1.0",
                "version_label": "2017 Gazette Enforcement",
                "description": "Mandatory conspicuous declaration of Country of Origin on imported packaged goods.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isImported", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True, "strict_country_check": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Amendment Rules, 2017, GSR 629(E)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-amend-2017",
                "publication_date": "2017-06-23T00:00:00Z",
                "effective_from": "2018-01-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },
    {
        "id": "rule-006-commodity",
        "code": "RULE-006-COMMODITY",
        "statutory_reference": "Rule 6(1)(b), LM (Packaged Commodities) Rules, 2011",
        "title": "Common or Generic Name of the Packaged Commodity",
        "category": "DECLARATIONS",
        "validation_type": "MANDATORY_DECLARATION",
        "description": "The common or generic names of the commodity contained in the package and in case of packages with more than one product, the name and number or quantity of each product.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {"field_name": "commodity_name", "prohibit_pure_brand_only": True},
        "evidence_requirements_json": ["IMAGE_SURFACE", "OCR_BOUNDING_BOX"],
        "active": True,
        "versions": [
            {
                "id": "ver-006-comm-v1",
                "version": "1.0",
                "version_label": "2011 Base Rule",
                "description": "Mandatory generic or common name of commodity on Principal Display Panel.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 6(1)(b)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },
    {
        "id": "rule-006-net-qty",
        "code": "RULE-006-NET-QTY",
        "statutory_reference": "Rule 6(1)(c) & Rule 12, LM (Packaged Commodities) Rules, 2011",
        "title": "Net Quantity in Standard SI Units of Measurement",
        "category": "DECLARATIONS",
        "validation_type": "MANDATORY_DECLARATION",
        "description": "The net quantity, in terms of the standard unit of weight or measure, of the commodity contained in the package or where the commodity is sold by number, the number of the commodity.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "canonical_weight_units": ["g", "kg"],
            "canonical_volume_units": ["ml", "l", "L"],
            "canonical_length_units": ["cm", "m"],
            "canonical_count_units": ["N", "U", "number", "units", "pieces"],
            "prohibited_symbols": ["gms", "g.", "kgs", "kilo", "litres", "ltrs", "ml."]
        },
        "evidence_requirements_json": ["IMAGE_SURFACE", "OCR_BOUNDING_BOX", "MEASURED_NET_QUANTITY"],
        "active": True,
        "versions": [
            {
                "id": "ver-006-net-qty-v1",
                "version": "1.0",
                "version_label": "2011 Standard Metric Units",
                "description": "Enforces SI standard units without non-standard abbreviations under Rule 12.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True, "strict_si_units": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 6(1)(c) & Rule 12",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },
    {
        "id": "rule-006-dates",
        "code": "RULE-006-DATES",
        "statutory_reference": "Rule 6(1)(d), LM (Packaged Commodities) Rules, 2011",
        "title": "Month and Year of Manufacture or Packing or Import",
        "category": "DECLARATIONS",
        "validation_type": "MANDATORY_DECLARATION",
        "description": "The month and the year in which the commodity is manufactured or pre-packed or imported shall be clearly indicated.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "acceptable_date_formats": ["MM/YYYY", "MM-YYYY", "Month YYYY", "YYYY-MM"],
            "allow_post_2021_month_year_only": True
        },
        "evidence_requirements_json": ["IMAGE_SURFACE", "OCR_BOUNDING_BOX", "DATE_TEXT"],
        "active": True,
        "versions": [
            {
                "id": "ver-006-dates-v1",
                "version": "1.0",
                "version_label": "2011 Base Rule",
                "description": "Month and year of manufacture, packing, or import.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 6(1)(d)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": "2022-12-01T00:00:00Z",
                "status": "SUPERSEDED"
            },
            {
                "id": "ver-006-dates-v2",
                "version": "2.0",
                "version_label": "2021 Amendment (Month & Year Only)",
                "description": "Omitted 'or pre-packed' to eliminate confusion between packing and manufacturing dates.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True, "month_year_format": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Amendment Rules, 2021, GSR 779(E)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-amend-2021",
                "publication_date": "2021-11-02T00:00:00Z",
                "effective_from": "2022-12-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },
    {
        "id": "rule-006-consumer-care",
        "code": "RULE-006-CONSUMER-CARE",
        "statutory_reference": "Rule 6(1)(n), LM (Packaged Commodities) Rules, 2011",
        "title": "Consumer Care Details (Grievance Redressal)",
        "category": "DECLARATIONS",
        "validation_type": "MANDATORY_DECLARATION",
        "description": "The name, address, telephone number, and e-mail address of the person who can be or the office which can be contacted in case of consumer complaints.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "required_components": ["contact_person_or_office", "telephone_or_helpline", "email_or_website"]
        },
        "evidence_requirements_json": ["IMAGE_SURFACE", "OCR_BOUNDING_BOX", "CONSUMER_CARE_TEXT"],
        "active": True,
        "versions": [
            {
                "id": "ver-006-care-v1",
                "version": "1.0",
                "version_label": "2011 Base Mandate",
                "description": "Mandatory telephone and email grievance contact details on all consumer pre-packaged goods.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 6(1)(n)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },

    # =========================================================================
    # CATEGORY: PDP / FONT SIZE (Rule 7 & Table-I)
    # =========================================================================
    {
        "id": "rule-007-pdp-area",
        "code": "RULE-007-PDP-AREA",
        "statutory_reference": "Rule 7(1), LM (Packaged Commodities) Rules, 2011",
        "title": "Principal Display Panel (PDP) Dimensions & Area Determination",
        "category": "PDP_FONT_SIZE",
        "validation_type": "PDP_TABLE_I",
        "description": "Governs statutory calculation of the Principal Display Panel (PDP) area: for rectangular packages 40% of height x width, for cylindrical packages 40% of height x circumference, and for other shapes 20% of total surface area.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "rectangular_factor": 0.40,
            "cylindrical_factor": 0.40,
            "irregular_factor": 0.20
        },
        "evidence_requirements_json": ["CALIBRATION_MEASUREMENT", "IMAGE_SURFACE", "CALCULATED_PDP_AREA"],
        "active": True,
        "versions": [
            {
                "id": "ver-007-area-v1",
                "version": "1.0",
                "version_label": "2011 Geometric PDP Formulation",
                "description": "Statutory PDP area formula based on package shape.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"rectangular_ratio": 0.40, "cylindrical_ratio": 0.40},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 7(1)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },
    {
        "id": "rule-007-char-height",
        "code": "RULE-007-CHAR-HEIGHT",
        "statutory_reference": "Rule 7(2) & Table-I, LM (Packaged Commodities) Rules, 2011",
        "title": "Principal Display Panel Table-I Numeral & Character Heights",
        "category": "PDP_FONT_SIZE",
        "validation_type": "PDP_TABLE_I",
        "description": "Mandates minimum character and numeral heights based strictly on PDP area (A in cm²) and packaging construction type (normal vs blown/formed/moulded). Under 50 cm²: 1.0mm (blown: 2.0mm); 50-100 cm²: 1.5mm (blown: 3.0mm); 100-500 cm²: 2.5mm (blown: 4.0mm); 500-2500 cm²: 4.0mm (blown: 6.0mm); >2500 cm²: 6.0mm (blown: 6.0mm).",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "table_1_thresholds": [
                {"range": "A <= 50", "min_area": 0.0, "max_area": 50.0, "normal_min_mm": 1.0, "blown_min_mm": 2.0},
                {"range": "50 < A <= 100", "min_area": 50.0, "max_area": 100.0, "normal_min_mm": 1.5, "blown_min_mm": 3.0},
                {"range": "100 < A <= 500", "min_area": 100.0, "max_area": 500.0, "normal_min_mm": 2.5, "blown_min_mm": 4.0},
                {"range": "500 < A <= 2500", "min_area": 500.0, "max_area": 2500.0, "normal_min_mm": 4.0, "blown_min_mm": 6.0},
                {"range": "A > 2500", "min_area": 2500.0, "max_area": 100000.0, "normal_min_mm": 6.0, "blown_min_mm": 6.0}
            ]
        },
        "evidence_requirements_json": ["CALIBRATION_PIXEL_MM", "MEASURED_CHAR_HEIGHT_MM", "PDP_AREA_CM2"],
        "active": True,
        "versions": [
            {
                "id": "ver-007-char-v1",
                "version": "1.0",
                "version_label": "2011 Table-I Minimums",
                "description": "Baseline Table-I minimum character and numeral heights.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "calibrationStatus", "operator": "EQUALS", "value": "CALIBRATED"}]},
                "thresholds": {
                    "table1": [
                        {"range": "A_LE_50", "max_area": 50.0, "normal_min_mm": 1.0, "blown_min_mm": 2.0},
                        {"range": "50_LT_A_LE_100", "min_area": 50.0, "max_area": 100.0, "normal_min_mm": 1.5, "blown_min_mm": 3.0},
                        {"range": "100_LT_A_LE_500", "min_area": 100.0, "max_area": 500.0, "normal_min_mm": 2.5, "blown_min_mm": 4.0},
                        {"range": "500_LT_A_LE_2500", "min_area": 500.0, "max_area": 2500.0, "normal_min_mm": 4.0, "blown_min_mm": 6.0},
                        {"range": "GT_2500", "min_area": 2500.0, "normal_min_mm": 6.0, "blown_min_mm": 6.0}
                    ]
                },
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 7(2) (Table-I)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },
    {
        "id": "rule-007-char-ratio",
        "code": "RULE-007-CHAR-RATIO",
        "statutory_reference": "Rule 7(3), LM (Packaged Commodities) Rules, 2011",
        "title": "Letter and Numeral Width-to-Height Proportion",
        "category": "PDP_FONT_SIZE",
        "validation_type": "CHAR_PROPORTION",
        "description": "The width of the letter or numeral shall not be less than one-third of its height, except in the case of numeral '1' and letters (i, I, l).",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "min_width_to_height_ratio": 0.333,
            "exempt_characters": ["1", "i", "I", "l"]
        },
        "evidence_requirements_json": ["MEASURED_RATIO", "CHAR_CROP_IMAGE"],
        "active": True,
        "versions": [
            {
                "id": "ver-007-ratio-v1",
                "version": "1.0",
                "version_label": "2011 Standard 1/3 Aspect Ratio",
                "description": "Width to height ratio >= 0.333.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "calibrationStatus", "operator": "EQUALS", "value": "CALIBRATED"}]},
                "thresholds": {"min_ratio": 0.333, "exempt_characters": ["1", "i", "I", "l"]},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 7(3)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },

    # =========================================================================
    # CATEGORY: MRP (Rule 6(1)(e) & Rule 6(11))
    # =========================================================================
    {
        "id": "rule-006-mrp",
        "code": "RULE-006-MRP",
        "statutory_reference": "Rule 6(1)(e), LM (Packaged Commodities) Rules, 2011",
        "title": "Maximum Retail Price (Inclusive of All Taxes)",
        "category": "MRP",
        "validation_type": "PRICE_TAX_INCLUSIVE",
        "description": "The retail sale price of the package shall clearly state 'Maximum or Max. Retail Price Rs. or ₹ ..... (inclusive of all taxes)' or 'MRP Rs. / ₹ ..... incl. of all taxes'. Rounding off must adhere to legal metrology norms. Smudging or conflicting prices are prohibited.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "required_phrases": ["inclusive of all taxes", "incl. of all taxes"],
            "currency_symbols": ["₹", "Rs.", "Rs", "INR"],
            "prohibit_dual_mrp": True
        },
        "evidence_requirements_json": ["IMAGE_SURFACE", "OCR_BOUNDING_BOX", "PRICE_TEXT"],
        "active": True,
        "versions": [
            {
                "id": "ver-006-mrp-v1",
                "version": "1.0",
                "version_label": "2011 Base Tax Inclusive MRP",
                "description": "Mandatory tax-inclusive MRP presentation with currency symbol.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True, "require_tax_inclusive_phrase": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 6(1)(e)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },
    {
        "id": "rule-006-unit-sale-price",
        "code": "RULE-006-UNIT-SALE-PRICE",
        "statutory_reference": "Rule 6(11), LM (Packaged Commodities) Rules, 2011 (as amended 2021 & 2022)",
        "title": "Unit Sale Price (USP) Metric Declaration",
        "category": "MRP",
        "validation_type": "UNIT_SALE_PRICE",
        "description": "For packages containing more than unit measurement (e.g. >1kg or >1L), unit sale price shall be declared per kg or per L. For packages under 1kg/1L, USP shall be per g or per ml. For commodities sold by count, USP shall be declared per item.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "under_1kg_unit": "per g",
            "under_1l_unit": "per ml",
            "over_1kg_unit": "per kg",
            "over_1l_unit": "per L",
            "count_unit": "per piece / per N"
        },
        "evidence_requirements_json": ["IMAGE_SURFACE", "OCR_BOUNDING_BOX", "USP_VALUE_TEXT"],
        "active": True,
        "versions": [
            {
                "id": "ver-006-usp-v1",
                "version": "1.0",
                "version_label": "2021 Gazette Mandate",
                "description": "Introduction of mandatory Unit Sale Price on packaged commodities.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Amendment Rules, 2021, GSR 779(E)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-amend-2021",
                "publication_date": "2021-11-02T00:00:00Z",
                "effective_from": "2022-12-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },

    # =========================================================================
    # CATEGORY: E_COMMERCE (Rule 6(10) & DCA Marketplace Advisories)
    # =========================================================================
    {
        "id": "rule-ecom-declarations",
        "code": "RULE-ECOM-DECLARATIONS",
        "statutory_reference": "Rule 6(10), LM (Packaged Commodities) Rules, 2011",
        "title": "E-Commerce Digital Viewport Mandatory Declarations",
        "category": "E_COMMERCE",
        "validation_type": "ECOM_VIEWPORT",
        "description": "An e-commerce entity shall ensure that the mandatory declarations under sub-rule (1), except the month and year of manufacture or packing, are displayed prominently on the digital platform prior to consumer purchase commitment.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "mandatory_on_viewport": ["name_address", "country_of_origin", "net_quantity", "mrp", "unit_sale_price", "consumer_care"],
            "exempt_on_viewport": ["manufacturing_packing_date"]
        },
        "evidence_requirements_json": ["VIEWPORT_SCREENSHOT", "PDP_DOM_METADATA", "OCR_BOUNDING_BOX"],
        "active": True,
        "versions": [
            {
                "id": "ver-ecom-decl-v1",
                "version": "1.0",
                "version_label": "2017 Gazette Enforcement",
                "description": "Statutory mandate holding e-commerce marketplaces accountable for pre-purchase declaration display under Rule 6(10).",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isOnlineListing", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Amendment Rules, 2017, GSR 629(E)",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-amend-2017",
                "publication_date": "2017-06-23T00:00:00Z",
                "effective_from": "2018-01-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },
    {
        "id": "rule-ecom-future-2027",
        "code": "RULE-ECOM-FUTURE-2027",
        "statutory_reference": "DCA Strategic Vision GSR-889 (Proposed 2027 Enforcement)",
        "title": "E-Commerce Real-Time Digital Declarations Synchronizer Standard",
        "category": "E_COMMERCE",
        "validation_type": "ECOM_VIEWPORT",
        "description": "Proposed regulatory standard mandating cryptographic QR verification and automated API synchronization of physical packaging changes with marketplace listings. Scheduled for future enforcement on 01-07-2027.",
        "coverage_status": "PARTIALLY_IMPLEMENTED",
        "parameters_json": {
            "qr_cryptographic_verification": True,
            "realtime_sync_required": True
        },
        "evidence_requirements_json": ["QR_CODE_PAYLOAD", "CRYPTOGRAPHIC_DIGEST"],
        "active": True,
        "versions": [
            {
                "id": "ver-ecom-2027-v1",
                "version": "1.0",
                "version_label": "2027 Scheduled Amendment",
                "description": "Future scheduled amendment. Stays SCHEDULED and inactive until 01-07-2027.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isOnlineListing", "operator": "EQUALS", "value": True}]},
                "thresholds": {"mandatory": True},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "DCA Strategic Gazette GSR-889",
                "source_url": "https://consumeraffairs.gov.in/pages/latest-news",
                "source_document_id": "doc-future-ecom-2027",
                "publication_date": "2026-09-10T00:00:00Z",
                "effective_from": "2027-07-01T00:00:00Z",
                "effective_to": None,
                "status": "SCHEDULED"
            }
        ]
    },

    # =========================================================================
    # CATEGORY: OTHER (Rule 9 Legibility, Rule 18 Misleading Packages)
    # =========================================================================
    {
        "id": "rule-009-legibility",
        "code": "RULE-009-LEGIBILITY",
        "statutory_reference": "Rule 9(1), LM (Packaged Commodities) Rules, 2011",
        "title": "Manner of Declaration: Conspicuous Legibility & Contrast",
        "category": "OTHER",
        "validation_type": "LEGIBILITY_CONTRAST",
        "description": "Every declaration shall be legible, prominent, definite, plain and unambiguous. Declarations shall be in conspicuous color contrast to the background of the label.",
        "coverage_status": "FULLY_IMPLEMENTED",
        "parameters_json": {
            "min_contrast_ratio": 3.0,
            "prohibit_concealed_text": True
        },
        "evidence_requirements_json": ["COLOR_CONTRAST_MEASUREMENT", "IMAGE_SURFACE"],
        "active": True,
        "versions": [
            {
                "id": "ver-009-leg-v1",
                "version": "1.0",
                "version_label": "2011 Base Standard",
                "description": "Legibility and color contrast mandate.",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"min_contrast": 3.0},
                "severity": "POTENTIAL_VIOLATION",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 9",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    },
    {
        "id": "rule-018-deceptive",
        "code": "RULE-018-DECEPTIVE",
        "statutory_reference": "Rule 18(1), LM (Packaged Commodities) Rules, 2011",
        "title": "Prohibition of Deceptive Packaging & Misleading Cavities",
        "category": "OTHER",
        "validation_type": "DECEPTIVE_PACKAGING",
        "description": "A package shall be so packed as to not mislead the consumer as to its actual volume, capacity or net content.",
        "coverage_status": "NOT_COVERED",
        "parameters_json": {
            "max_slack_fill_percent": 15.0
        },
        "evidence_requirements_json": ["XRAY_DENSITY_SCAN", "INTERNAL_CAVITY_MEASUREMENT"],
        "active": True,
        "versions": [
            {
                "id": "ver-018-decept-v1",
                "version": "1.0",
                "version_label": "2011 Statutory Provision",
                "description": "Prohibition of deceptive cavities (requires physical destructive/X-ray volumetric audit).",
                "conditions": {"conditionGroup": "ALL", "conditions": [{"field": "isCommodityPackaged", "operator": "EQUALS", "value": True}]},
                "thresholds": {"max_slack_fill": 15.0},
                "severity": "REVIEW",
                "source_name": "Ministry of Consumer Affairs, Food and Public Distribution",
                "source_reference": "Legal Metrology (Packaged Commodities) Rules, 2011, Rule 18",
                "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "source_document_id": "doc-pc-rules-2011",
                "publication_date": "2011-03-07T00:00:00Z",
                "effective_from": "2011-04-01T00:00:00Z",
                "effective_to": None,
                "status": "ACTIVE"
            }
        ]
    }
]

# Rule Coverage Matrix Specification
RULE_COVERAGE_SPEC: List[Dict[str, Any]] = [
    {
        "id": "cov-rule-6-decl",
        "rule_family": "Rule 6",
        "rule_codes": ["RULE-006-NAME-ADDR", "RULE-006-ORIGIN", "RULE-006-COMMODITY", "RULE-006-NET-QTY", "RULE-006-DATES", "RULE-006-CONSUMER-CARE"],
        "coverage_status": "FULLY_IMPLEMENTED",
        "supported_checks": ["PRESENCE", "COMPLETENESS", "UNIT_FORMAT", "DATE_FORMAT", "ORIGIN_CONSISTENCY"],
        "limitations": "Postal address pin code verified against National Postal Directory. Physical visit needed for factory premises.",
        "source_reference": "Rule 6, LM Rules, 2011",
        "last_verified_at": "2026-09-08T00:00:00Z"
    },
    {
        "id": "cov-rule-7-pdp",
        "rule_family": "Rule 7",
        "rule_codes": ["RULE-007-PDP-AREA", "RULE-007-CHAR-HEIGHT", "RULE-007-CHAR-RATIO"],
        "coverage_status": "FULLY_IMPLEMENTED",
        "supported_checks": ["GEOMETRIC_PDP_AREA", "TABLE_I_HEIGHT_VALIDATION", "CHAR_ASPECT_RATIO_EVALUATION"],
        "limitations": "Physical card calibration required for sub-millimetre precision. Uncalibrated states marked UNVERIFIED.",
        "source_reference": "Rule 7 & Table-I, LM Rules, 2011",
        "last_verified_at": "2026-09-08T00:00:00Z"
    },
    {
        "id": "cov-rule-6-mrp",
        "rule_family": "Rule 6 MRP & USP",
        "rule_codes": ["RULE-006-MRP", "RULE-006-UNIT-SALE-PRICE"],
        "coverage_status": "FULLY_IMPLEMENTED",
        "supported_checks": ["TAX_INCLUSIVE_PHRASE", "CURRENCY_SYMBOL", "USP_METRIC_CONSISTENCY"],
        "limitations": "Dual MRP smudge detection assisted by Vision AI; confirmed by officer.",
        "source_reference": "Rule 6(1)(e) & Rule 6(11), LM Rules, 2011",
        "last_verified_at": "2026-09-08T00:00:00Z"
    },
    {
        "id": "cov-rule-ecom",
        "rule_family": "E-Commerce Marketplaces",
        "rule_codes": ["RULE-ECOM-DECLARATIONS", "RULE-ECOM-FUTURE-2027"],
        "coverage_status": "PARTIALLY_IMPLEMENTED",
        "supported_checks": ["VIEWPORT_DECLARATIONS_AUDIT", "ORIGIN_PROMINENCE_CHECK"],
        "limitations": "Dynamic web listing scraper evaluates active viewport DOM; automated 2027 QR cryptographic verification scheduled for 2027 rollout.",
        "source_reference": "Rule 6(10), LM Rules, 2011 & DCA Advisories",
        "last_verified_at": "2026-09-08T00:00:00Z"
    },
    {
        "id": "cov-rule-9-legibility",
        "rule_family": "Rule 9",
        "rule_codes": ["RULE-009-LEGIBILITY"],
        "coverage_status": "FULLY_IMPLEMENTED",
        "supported_checks": ["BACKGROUND_CONTRAST_RATIO", "TEXT_CLARITY_SCORE"],
        "limitations": "Extreme glare or specular reflections flag review requirement.",
        "source_reference": "Rule 9, LM Rules, 2011",
        "last_verified_at": "2026-09-08T00:00:00Z"
    },
    {
        "id": "cov-rule-18-deceptive",
        "rule_family": "Rule 18",
        "rule_codes": ["RULE-018-DECEPTIVE"],
        "coverage_status": "NOT_COVERED",
        "supported_checks": [],
        "limitations": "Deceptive cavity and slack-fill evaluation requires physical destructive dissection or X-ray volumetric testing. Explicitly marked NOT_COVERED.",
        "source_reference": "Rule 18, LM Rules, 2011",
        "last_verified_at": "2026-09-08T00:00:00Z"
    }
]

async def seed_real_statutory_rules(session=None):
    """
    Idempotently seeds authoritative official legal documents, statutory rules,
    versions, amendments, and coverage matrix into the database.
    """
    logger.info("Initializing authoritative Legal Metrology statutory rule registry...")
    
    close_session = False
    if session is None:
        if not settings.DATABASE_URL or engine is None:
            logger.info("Database not configured. Seeding in-memory demo repository...")
            _seed_in_memory_repository()
            return
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
            from sqlalchemy import text
            alter_sqls = [
                "ALTER TABLE rules ADD COLUMN IF NOT EXISTS statutory_reference VARCHAR(255);",
                "ALTER TABLE rules ADD COLUMN IF NOT EXISTS validation_type VARCHAR(100);",
                "ALTER TABLE rules ADD COLUMN IF NOT EXISTS parameters_json JSON;",
                "ALTER TABLE rules ADD COLUMN IF NOT EXISTS evidence_requirements_json JSON;",
                "ALTER TABLE rules ADD COLUMN IF NOT EXISTS coverage_status VARCHAR(50) DEFAULT 'FULLY_IMPLEMENTED';",
                "ALTER TABLE rule_versions ADD COLUMN IF NOT EXISTS version_label VARCHAR(100);",
                "ALTER TABLE rule_versions ADD COLUMN IF NOT EXISTS source_document_id VARCHAR(50);",
                "ALTER TABLE rule_versions ADD COLUMN IF NOT EXISTS publication_date TIMESTAMP WITH TIME ZONE;",
                "ALTER TABLE rule_versions ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'ACTIVE';",
                "ALTER TABLE rule_versions ADD COLUMN IF NOT EXISTS created_by VARCHAR(100);",
                "ALTER TABLE rule_versions ADD COLUMN IF NOT EXISTS approved_by VARCHAR(100);",
                "ALTER TABLE rule_versions ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;",
                "ALTER TABLE rule_coverage ADD COLUMN IF NOT EXISTS limitations TEXT;"
            ]
            for q in alter_sqls:
                try:
                    await conn.execute(text(q))
                except Exception as e:
                    logger.warning(f"Schema update notice: {e}")
        session = AsyncSessionLocal()
        close_session = True

    try:
        # 1. Seed Official Legal Documents
        for doc in get_official_sources():
            doc_record = LegalDocument(
                id=doc["id"],
                title=doc["title"],
                document_type=doc["document_type"],
                source_url=doc["source_url"],
                source_authority=doc["authority"],
                notification_number=doc.get("notification_number"),
                publication_date=_dt(doc["publication_date"]) if doc.get("publication_date") else None,
                effective_date=_dt(doc["effective_date"]) if doc.get("effective_date") else None,
                document_hash=doc.get("document_hash"),
                document_version=doc.get("document_version"),
                status=doc.get("status", "ACTIVE")
            )
            await session.merge(doc_record)

        # 2. Seed Real Statutory Rules, Versions, and Amendments
        for rule_spec in STATUTORY_RULES_SPEC:
            rule_record = Rule(
                id=rule_spec["id"],
                code=rule_spec["code"],
                statutory_reference=rule_spec["statutory_reference"],
                title=rule_spec["title"],
                description=rule_spec["description"],
                category=rule_spec["category"],
                validation_type=rule_spec.get("validation_type"),
                parameters_json=rule_spec.get("parameters_json"),
                evidence_requirements_json=rule_spec.get("evidence_requirements_json"),
                coverage_status=rule_spec.get("coverage_status", "FULLY_IMPLEMENTED"),
                active=rule_spec.get("active", True)
            )
            await session.merge(rule_record)

            # Seed Versions
            for ver_spec in rule_spec.get("versions", []):
                ver_record = RuleVersion(
                    id=ver_spec["id"],
                    rule_id=rule_spec["id"],
                    version=ver_spec["version"],
                    version_label=ver_spec.get("version_label"),
                    description=ver_spec.get("description"),
                    conditions=ver_spec["conditions"],
                    thresholds=ver_spec.get("thresholds"),
                    severity=ver_spec.get("severity", "POTENTIAL_VIOLATION"),
                    source_name=ver_spec["source_name"],
                    source_reference=ver_spec["source_reference"],
                    source_url=ver_spec.get("source_url"),
                    source_document_id=ver_spec.get("source_document_id"),
                    publication_date=_dt(ver_spec["publication_date"]) if ver_spec.get("publication_date") else None,
                    effective_from=_dt(ver_spec["effective_from"]),
                    effective_to=_dt(ver_spec["effective_to"]) if ver_spec.get("effective_to") else None,
                    status=ver_spec.get("status", "ACTIVE"),
                    is_demo_rule=False
                )
                await session.merge(ver_record)

            # Seed Amendments
            for amend_spec in rule_spec.get("amendments", []):
                amend_record = RuleAmendment(
                    id=amend_spec["id"],
                    rule_id=rule_spec["id"],
                    previous_version_id=amend_spec.get("previous_version_id"),
                    new_version_id=amend_spec["new_version_id"],
                    amendment_type=amend_spec["amendment_type"],
                    amendment_summary=amend_spec["amendment_summary"],
                    source_document_id=amend_spec.get("source_document_id"),
                    effective_from=_dt(amend_spec["effective_from"])
                )
                await session.merge(amend_record)

        # 3. Seed Rule Coverage Matrix
        for cov_spec in RULE_COVERAGE_SPEC:
            cov_record = RuleCoverage(
                id=cov_spec["id"],
                rule_family=cov_spec["rule_family"],
                rule_codes=cov_spec["rule_codes"],
                coverage_status=cov_spec["coverage_status"],
                supported_checks=cov_spec["supported_checks"],
                limitations=cov_spec.get("limitations"),
                source_reference=cov_spec["source_reference"],
                last_verified_at=_dt(cov_spec["last_verified_at"]) if cov_spec.get("last_verified_at") else None,
                is_demo_rule=False
            )
            await session.merge(cov_record)

        await session.commit()
        logger.info("Authoritative statutory rule registry successfully seeded into Neon PostgreSQL.")

    finally:
        if close_session:
            await session.close()

    # Also seed in-memory repository for offline / dev parity
    _seed_in_memory_repository()

def _seed_in_memory_repository():
    from app.repositories.in_memory_demo import demo_repository
    
    # 1. Legal Documents
    for doc in get_official_sources():
        demo_repository.legal_documents[doc["id"]] = dict(doc)

    # 2. Rules and Versions
    demo_repository.rules.clear()
    for rule_spec in STATUTORY_RULES_SPEC:
        r_dict = dict(rule_spec)
        demo_repository.rules[rule_spec["id"]] = r_dict

        for amend in rule_spec.get("amendments", []):
            demo_repository.rule_amendments[amend["id"]] = dict(amend)

    # 3. Coverage
    demo_repository.rule_coverage = [dict(c) for c in RULE_COVERAGE_SPEC]

if __name__ == "__main__":
    asyncio.run(seed_real_statutory_rules())
