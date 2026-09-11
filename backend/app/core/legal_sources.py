"""
MAANAK Centralized Legal Source Registry
Authoritative official sources from the Department of Consumer Affairs (DCA),
Ministry of Consumer Affairs, Food and Public Distribution, Government of India.
"""

from typing import List, Dict, Any, Optional
import hashlib
from datetime import datetime, timezone

def compute_document_hash(title: str, authority: str, notification: Optional[str], effective_date: str) -> str:
    seed = f"{title}|{authority}|{notification or ''}|{effective_date}".encode("utf-8")
    return hashlib.sha256(seed).hexdigest()

OFFICIAL_LEGAL_SOURCES: List[Dict[str, Any]] = [
    {
        "id": "doc-dca-overview",
        "title": "Department of Consumer Affairs — Legal Metrology Overview",
        "authority": "Department of Consumer Affairs, Government of India",
        "document_type": "OFFICIAL_PORTAL",
        "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-overview",
        "notification_number": None,
        "publication_date": "2010-01-01T00:00:00Z",
        "effective_date": "2011-04-01T00:00:00Z",
        "document_version": "1.0",
        "status": "ACTIVE",
        "description": "Statutory overview of weights and measures regulation, packaged commodity rules, and enforcement frameworks in India.",
        "document_hash": compute_document_hash("Department of Consumer Affairs — Legal Metrology Overview", "Department of Consumer Affairs, Government of India", None, "2011-04-01T00:00:00Z")
    },
    {
        "id": "doc-lm-act-2009",
        "title": "The Legal Metrology Act, 2009 (Act No. 1 of 2010)",
        "authority": "Parliament of India / Ministry of Law and Justice",
        "document_type": "PRIMARY_ACT",
        "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
        "notification_number": "Act No. 1 of 2010",
        "publication_date": "2010-01-14T00:00:00Z",
        "effective_date": "2011-04-01T00:00:00Z",
        "document_version": "2009.1",
        "status": "ACTIVE",
        "description": "Parent statutory enactment establishing standard weights, measures, and statutory inspection mandates across India.",
        "document_hash": compute_document_hash("The Legal Metrology Act, 2009 (Act No. 1 of 2010)", "Parliament of India / Ministry of Law and Justice", "Act No. 1 of 2010", "2011-04-01T00:00:00Z")
    },
    {
        "id": "doc-pc-rules-2011",
        "title": "Legal Metrology (Packaged Commodities) Rules, 2011",
        "authority": "Ministry of Consumer Affairs, Food and Public Distribution",
        "document_type": "STATUTORY_RULES",
        "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
        "notification_number": "G.S.R. 202(E)",
        "publication_date": "2011-03-07T00:00:00Z",
        "effective_date": "2011-04-01T00:00:00Z",
        "document_version": "2011.BASE",
        "status": "ACTIVE",
        "description": "Core regulations governing mandatory label declarations (Rule 6), Principal Display Panel numeral/character heights (Rule 7, Table-I), legibility (Rule 9), and retail sale standards.",
        "document_hash": compute_document_hash("Legal Metrology (Packaged Commodities) Rules, 2011", "Ministry of Consumer Affairs, Food and Public Distribution", "G.S.R. 202(E)", "2011-04-01T00:00:00Z")
    },
    {
        "id": "doc-amend-2017",
        "title": "Legal Metrology (Packaged Commodities) Amendment Rules, 2017",
        "authority": "Ministry of Consumer Affairs, Food and Public Distribution",
        "document_type": "GAZETTE_AMENDMENT",
        "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
        "notification_number": "G.S.R. 629(E)",
        "publication_date": "2017-06-23T00:00:00Z",
        "effective_date": "2018-01-01T00:00:00Z",
        "document_version": "2017.1",
        "status": "SUPERSEDED",
        "description": "Introduced mandatory e-commerce pre-purchase declarations on digital viewports (Rule 6(10)), enhanced font sizes, and barcode/QR requirements.",
        "document_hash": compute_document_hash("Legal Metrology (Packaged Commodities) Amendment Rules, 2017", "Ministry of Consumer Affairs, Food and Public Distribution", "G.S.R. 629(E)", "2018-01-01T00:00:00Z")
    },
    {
        "id": "doc-amend-2021",
        "title": "Legal Metrology (Packaged Commodities) Amendment Rules, 2021",
        "authority": "Ministry of Consumer Affairs, Food and Public Distribution",
        "document_type": "GAZETTE_AMENDMENT",
        "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
        "notification_number": "G.S.R. 779(E)",
        "publication_date": "2021-11-02T00:00:00Z",
        "effective_date": "2022-12-01T00:00:00Z",
        "document_version": "2021.1",
        "status": "SUPERSEDED",
        "description": "Introduced Unit Sale Price (USP) mandate (Rule 6(11)), removed Schedule II prescribed standard packaging sizes, and mandated month & year of manufacture/import only.",
        "document_hash": compute_document_hash("Legal Metrology (Packaged Commodities) Amendment Rules, 2021", "Ministry of Consumer Affairs, Food and Public Distribution", "G.S.R. 779(E)", "2022-12-01T00:00:00Z")
    },
    {
        "id": "doc-amend-2022-usp",
        "title": "Legal Metrology (Packaged Commodities) Amendment Rules, 2022 (Unit Sale Price Specification)",
        "authority": "Ministry of Consumer Affairs, Food and Public Distribution",
        "document_type": "GAZETTE_AMENDMENT",
        "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
        "notification_number": "G.S.R. 226(E)",
        "publication_date": "2022-03-28T00:00:00Z",
        "effective_date": "2022-12-01T00:00:00Z",
        "document_version": "2022.1",
        "status": "ACTIVE",
        "description": "Refined Unit Sale Price display rules (per gram / per ml for net quantities under 1kg/1L, per kg / per L for >= 1kg/1L, and per item for count).",
        "document_hash": compute_document_hash("Legal Metrology (Packaged Commodities) Amendment Rules, 2022 (Unit Sale Price Specification)", "Ministry of Consumer Affairs, Food and Public Distribution", "G.S.R. 226(E)", "2022-12-01T00:00:00Z")
    },
    {
        "id": "doc-amend-2022-spare",
        "title": "Legal Metrology (Packaged Commodities) (Second Amendment) Rules, 2022",
        "authority": "Ministry of Consumer Affairs, Food and Public Distribution",
        "document_type": "GAZETTE_AMENDMENT",
        "source_url": "https://consumeraffairs.gov.in/pages/legal-metrology-act",
        "notification_number": "G.S.R. 520(E)",
        "publication_date": "2022-07-06T00:00:00Z",
        "effective_date": "2022-07-06T00:00:00Z",
        "document_version": "2022.2",
        "status": "ACTIVE",
        "description": "Provided relaxation for electronic products, automotive spare parts, and agricultural grain packages.",
        "document_hash": compute_document_hash("Legal Metrology (Packaged Commodities) (Second Amendment) Rules, 2022", "Ministry of Consumer Affairs, Food and Public Distribution", "G.S.R. 520(E)", "2022-07-06T00:00:00Z")
    },
    {
        "id": "doc-amend-2023",
        "title": "Legal Metrology (Packaged Commodities) Amendment Rules, 2023 & Jan Vishwas Act",
        "authority": "Ministry of Consumer Affairs, Food and Public Distribution",
        "document_type": "GAZETTE_AMENDMENT",
        "source_url": "https://consumeraffairs.gov.in/pages/latest-news",
        "notification_number": "G.S.R. 721(E)",
        "publication_date": "2023-10-06T00:00:00Z",
        "effective_date": "2024-01-01T00:00:00Z",
        "document_version": "2024.1",
        "status": "ACTIVE",
        "description": "Statutory amendment aligning penalties with the Jan Vishwas (Amendment of Provisions) Act and clarifying unbranded agricultural commodities.",
        "document_hash": compute_document_hash("Legal Metrology (Packaged Commodities) Amendment Rules, 2023 & Jan Vishwas Act", "Ministry of Consumer Affairs, Food and Public Distribution", "G.S.R. 721(E)", "2024-01-01T00:00:00Z")
    },
    {
        "id": "doc-dca-news-portal",
        "title": "Department of Consumer Affairs — Latest News & Enforcement Advisories",
        "authority": "Department of Consumer Affairs, Government of India",
        "document_type": "OFFICIAL_ADVISORY",
        "source_url": "https://consumeraffairs.gov.in/pages/latest-news",
        "notification_number": "DCA-ADVISORY-2024-ECOM",
        "publication_date": "2024-04-15T00:00:00Z",
        "effective_date": "2024-05-01T00:00:00Z",
        "document_version": "2024.ECOM",
        "status": "ACTIVE",
        "description": "Continuous regulatory advisories for e-commerce platforms regarding clear display of MRP, Unit Sale Price, and Country of Origin on digital listings.",
        "document_hash": compute_document_hash("Department of Consumer Affairs — Latest News & Enforcement Advisories", "Department of Consumer Affairs, Government of India", "DCA-ADVISORY-2024-ECOM", "2024-05-01T00:00:00Z")
    },
    {
        "id": "doc-future-ecom-2027",
        "title": "DCA Strategic Vision: E-Commerce Digital Viewport AI-Audit Standard",
        "authority": "Ministry of Consumer Affairs, Food and Public Distribution",
        "document_type": "PROPOSED_AMENDMENT",
        "source_url": "https://consumeraffairs.gov.in/pages/latest-news",
        "notification_number": "DCA-PROPOSED-2026/GSR-889",
        "publication_date": "2026-09-10T00:00:00Z",
        "effective_date": "2027-07-01T00:00:00Z",
        "document_version": "2027.PROPOSED",
        "status": "SCHEDULED",
        "description": "Future scheduled gazette requirement mandating machine-readable QR verification and real-time declaration synchronization on all marketplace listings. Scheduled for future enforcement.",
        "document_hash": compute_document_hash("DCA Strategic Vision: E-Commerce Digital Viewport AI-Audit Standard", "Ministry of Consumer Affairs, Food and Public Distribution", "DCA-PROPOSED-2026/GSR-889", "2027-07-01T00:00:00Z")
    }
]

def get_official_sources() -> List[Dict[str, Any]]:
    return OFFICIAL_LEGAL_SOURCES

def get_source_by_id(source_id: str) -> Optional[Dict[str, Any]]:
    for s in OFFICIAL_LEGAL_SOURCES:
        if s["id"] == source_id:
            return s
    return None
