from datetime import datetime, timezone
import uuid
from sqlalchemy import (
    Column, String, Boolean, DateTime, Integer, Float, ForeignKey, Text, JSON
)
from sqlalchemy.orm import relationship
from app.core.database import Base

def generate_uuid() -> str:
    return str(uuid.uuid4())

def get_utc_now() -> datetime:
    return datetime.now(timezone.utc)

class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    email = Column(String(255), unique=True, nullable=False, index=True)
    full_name = Column(String(255), nullable=False)
    officer_id = Column(String(100), nullable=False, index=True)
    department = Column(String(255), nullable=False, default="Legal Metrology")
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False, default="INSPECTOR")  # INSPECTOR, SUPERVISOR, ADMIN
    active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_now)

class Product(Base):
    __tablename__ = "products"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    name = Column(String(255), nullable=False, index=True)
    brand = Column(String(255), nullable=True, index=True)
    category = Column(String(100), nullable=False, index=True)
    
    # Semantic roles
    manufacturer_name = Column(String(255), nullable=True)
    manufacturer_address = Column(Text, nullable=True)
    packer_name = Column(String(255), nullable=True)
    packer_address = Column(Text, nullable=True)
    importer_name = Column(String(255), nullable=True)
    importer_address = Column(Text, nullable=True)

    net_quantity = Column(String(50), nullable=True)
    net_quantity_unit = Column(String(20), nullable=True)
    barcode = Column(String(100), nullable=True, index=True)
    country_of_origin = Column(String(100), nullable=True)
    
    product_identity_fingerprint = Column(String(64), nullable=True, index=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_now)
    updated_at = Column(DateTime(timezone=True), default=get_utc_now, onupdate=get_utc_now)

    inspections = relationship("Inspection", back_populates="product")
    label_versions = relationship("LabelVersion", back_populates="product")

class Inspection(Base):
    __tablename__ = "inspections"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_code = Column(String(50), unique=True, nullable=False, index=True)
    inspector_id = Column(String(36), ForeignKey("users.id"), nullable=False, index=True)
    product_id = Column(String(36), ForeignKey("products.id"), nullable=True, index=True)
    
    inspection_type = Column(String(50), nullable=False, default="PHYSICAL")  # PHYSICAL, ONLINE_LISTING
    inspection_date = Column(DateTime(timezone=True), default=get_utc_now, index=True)
    location = Column(String(255), nullable=False)
    seller_name = Column(String(255), nullable=True)
    business_name = Column(String(255), nullable=True)
    
    # Status: DRAFT, ANALYSING, NEEDS_REVIEW, READY, FINALIZED, ARCHIVED
    status = Column(String(50), nullable=False, default="DRAFT", index=True)
    score = Column(Float, nullable=True)
    
    # Package & Calibration Context
    package_type = Column(String(50), nullable=True, default="RECTANGULAR")
    package_construction_type = Column(String(50), nullable=True, default="NORMAL")  # NORMAL, BLOWN_FORMED_MOLDED, UNKNOWN
    calibration_status = Column(String(50), nullable=True, default="NOT_CALIBRATED")  # CALIBRATED, PARTIALLY_CALIBRATED, UNCERTAIN, NOT_CALIBRATED
    calibration_data = Column(JSON, nullable=True)  # {method, point1, point2, knownDistance, pxPerMm}
    pdp_data = Column(JSON, nullable=True)  # {areaCm2, method, confidence}
    
    applied_rule_version = Column(String(50), nullable=True)
    rule_snapshot = Column(JSON, nullable=True)
    notes = Column(Text, nullable=True)
    
    created_at = Column(DateTime(timezone=True), default=get_utc_now)
    updated_at = Column(DateTime(timezone=True), default=get_utc_now, onupdate=get_utc_now)
    finalized_at = Column(DateTime(timezone=True), nullable=True)

    product = relationship("Product", back_populates="inspections")
    images = relationship("InspectionImage", back_populates="inspection", cascade="all, delete-orphan")
    declarations = relationship("Declaration", back_populates="inspection", cascade="all, delete-orphan")
    checks = relationship("ComplianceCheck", back_populates="inspection", cascade="all, delete-orphan")
    violations = relationship("Violation", back_populates="inspection", cascade="all, delete-orphan")
    evidence_items = relationship("Evidence", back_populates="inspection", cascade="all, delete-orphan")

class InspectionImage(Base):
    __tablename__ = "inspection_images"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=False, index=True)
    surface_type = Column(String(50), nullable=False, default="FRONT")  # FRONT, BACK, LEFT, RIGHT, TOP, BOTTOM, MRP_AREA, OTHER
    original_path = Column(String(500), nullable=False)
    thumbnail_path = Column(String(500), nullable=True)
    width = Column(Integer, nullable=True)
    height = Column(Integer, nullable=True)
    mime_type = Column(String(100), nullable=False, default="image/jpeg")
    file_size = Column(Integer, nullable=False, default=0)
    
    quality_score = Column(Float, nullable=True)
    quality_assessment = Column(String(50), nullable=True, default="GOOD")  # GOOD, NEEDS_RETAKE
    quality_details = Column(JSON, nullable=True)
    
    created_at = Column(DateTime(timezone=True), default=get_utc_now)

    inspection = relationship("Inspection", back_populates="images")

class Declaration(Base):
    __tablename__ = "declarations"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=False, index=True)
    field_name = Column(String(100), nullable=False, index=True)
    
    ai_value = Column(Text, nullable=True)
    verified_value = Column(Text, nullable=True)
    unit = Column(String(50), nullable=True)
    confidence = Column(Float, nullable=False, default=0.0)
    
    source_image_id = Column(String(36), nullable=True)
    source_block_id = Column(String(50), nullable=True)
    source_text = Column(Text, nullable=True)
    bbox = Column(JSON, nullable=True)  # {x, y, width, height}
    
    # PRESENCE, CORRECTNESS, COMPLETENESS, PLACEMENT, LEGIBILITY
    presence_status = Column(String(50), nullable=False, default="DETECTED")
    correctness_status = Column(String(50), nullable=False, default="VALID")
    verification_status = Column(String(50), nullable=False, default="PENDING")  # PENDING, VERIFIED, REJECTED, EDITED
    provenance = Column(String(50), nullable=False, default="AI_EXTRACTED")  # AI_EXTRACTED, INSPECTOR_VERIFIED, INSPECTOR_ADDED
    
    verified_by = Column(String(36), nullable=True)
    verified_at = Column(DateTime(timezone=True), nullable=True)
    notes = Column(Text, nullable=True)
    
    created_at = Column(DateTime(timezone=True), default=get_utc_now)

    inspection = relationship("Inspection", back_populates="declarations")

class Rule(Base):
    __tablename__ = "rules"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    code = Column(String(100), unique=True, nullable=False, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(100), nullable=False, default="GENERAL")
    active = Column(Boolean, default=True, index=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_now)
    updated_at = Column(DateTime(timezone=True), default=get_utc_now, onupdate=get_utc_now)

    versions = relationship("RuleVersion", back_populates="rule", cascade="all, delete-orphan")

class RuleVersion(Base):
    __tablename__ = "rule_versions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    rule_id = Column(String(36), ForeignKey("rules.id"), nullable=False, index=True)
    version = Column(String(50), nullable=False)
    description = Column(Text, nullable=True)
    
    conditions = Column(JSON, nullable=False)  # Controlled condition model: {conditionGroup: ALL, conditions: [...]}
    thresholds = Column(JSON, nullable=True)   # Structured thresholds (PDP area table, character proportion, etc.)
    severity = Column(String(50), nullable=False, default="POTENTIAL_VIOLATION")  # PASS, REVIEW, POTENTIAL_VIOLATION
    
    source_name = Column(String(255), nullable=False)
    source_reference = Column(String(255), nullable=False)
    source_url = Column(String(500), nullable=True)
    
    effective_from = Column(DateTime(timezone=True), nullable=False)
    effective_to = Column(DateTime(timezone=True), nullable=True)
    is_demo_rule = Column(Boolean, default=False)
    
    created_at = Column(DateTime(timezone=True), default=get_utc_now)

    rule = relationship("Rule", back_populates="versions")

class ComplianceCheck(Base):
    __tablename__ = "compliance_checks"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=False, index=True)
    rule_version_id = Column(String(36), ForeignKey("rule_versions.id"), nullable=True)
    
    check_type = Column(String(100), nullable=False)  # MANDATORY_DECLARATION, CHARACTER_HEIGHT, CHARACTER_PROPORTION, READABILITY, PLACEMENT, etc.
    field_name = Column(String(100), nullable=False)
    input_value = Column(Text, nullable=True)
    expected_condition = Column(Text, nullable=True)
    
    # PASS, REVIEW, POTENTIAL_VIOLATION, UNVERIFIED
    result = Column(String(50), nullable=False, default="PASS")
    confidence = Column(Float, nullable=False, default=1.0)
    explanation = Column(Text, nullable=False)
    evidence_id = Column(String(36), nullable=True)
    
    created_at = Column(DateTime(timezone=True), default=get_utc_now)

    inspection = relationship("Inspection", back_populates="checks")

class Violation(Base):
    __tablename__ = "violations"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=False, index=True)
    compliance_check_id = Column(String(36), ForeignKey("compliance_checks.id"), nullable=True)
    
    type = Column(String(100), nullable=False)  # MISSING_DECLARATION, NON_STANDARD_DECLARATION, ILLEGIBLE_TEXT, INSUFFICIENT_FONT_SIZE, etc.
    severity = Column(String(50), nullable=False, default="MEDIUM")
    confidence = Column(Float, nullable=False, default=1.0)
    
    # AI_DETECTED, REVIEW_REQUIRED, CONFIRMED, REJECTED, INSPECTOR_ADDED
    status = Column(String(50), nullable=False, default="AI_DETECTED")
    provenance = Column(String(50), nullable=False, default="AI_DETECTED")
    
    ai_explanation = Column(Text, nullable=True)
    inspector_comment = Column(Text, nullable=True)
    confirmed_by = Column(String(36), nullable=True)
    confirmed_at = Column(DateTime(timezone=True), nullable=True)
    
    created_at = Column(DateTime(timezone=True), default=get_utc_now)

    inspection = relationship("Inspection", back_populates="violations")

class Evidence(Base):
    __tablename__ = "evidence"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=False, index=True)
    image_id = Column(String(36), ForeignKey("inspection_images.id"), nullable=True)
    finding_id = Column(String(36), nullable=True)
    
    original_path = Column(String(500), nullable=False)
    crop_path = Column(String(500), nullable=True)
    bbox = Column(JSON, nullable=True)
    description = Column(Text, nullable=True)
    
    created_at = Column(DateTime(timezone=True), default=get_utc_now)

    inspection = relationship("Inspection", back_populates="evidence_items")

class Report(Base):
    __tablename__ = "reports"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    inspection_id = Column(String(36), ForeignKey("inspections.id"), nullable=False, index=True)
    report_version = Column(Integer, nullable=False, default=1)
    
    pdf_path = Column(String(500), nullable=True)
    pdf_sha256 = Column(String(64), nullable=True)
    pdf_generated_at = Column(DateTime(timezone=True), nullable=True)
    
    docx_path = Column(String(500), nullable=True)
    docx_sha256 = Column(String(64), nullable=True)
    docx_generated_at = Column(DateTime(timezone=True), nullable=True)
    
    # NOT_GENERATED, GENERATING, GENERATED_LOCAL, ARCHIVED, ARCHIVE_FAILED
    archival_status = Column(String(50), nullable=False, default="NOT_GENERATED")
    generated_by = Column(String(36), nullable=True)
    created_at = Column(DateTime(timezone=True), default=get_utc_now)

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), nullable=False, index=True)
    role = Column(String(50), nullable=False)
    action = Column(String(100), nullable=False, index=True)
    resource_type = Column(String(100), nullable=False)
    resource_id = Column(String(100), nullable=False)
    old_value = Column(JSON, nullable=True)
    new_value = Column(JSON, nullable=True)
    timestamp = Column(DateTime(timezone=True), default=get_utc_now, index=True)
    metadata_ = Column("metadata", JSON, nullable=True)

class LabelVersion(Base):
    __tablename__ = "label_versions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    product_id = Column(String(36), ForeignKey("products.id"), nullable=False, index=True)
    inspection_id = Column(String(36), nullable=False)
    image_id = Column(String(36), nullable=True)
    label_version = Column(String(50), nullable=False)
    visual_hash = Column(String(64), nullable=False)
    ocr_summary = Column(Text, nullable=True)
    mrp = Column(String(50), nullable=True)
    net_quantity = Column(String(50), nullable=True)
    captured_at = Column(DateTime(timezone=True), default=get_utc_now)

    product = relationship("Product", back_populates="label_versions")

class RuleCoverage(Base):
    __tablename__ = "rule_coverage"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    rule_family = Column(String(100), nullable=False)  # Rule 6, Rule 7, Rule 8, etc.
    rule_codes = Column(JSON, nullable=False)
    coverage_status = Column(String(50), nullable=False)  # FULLY_IMPLEMENTED, PARTIALLY_IMPLEMENTED, NOT_COVERED
    supported_checks = Column(JSON, nullable=False)
    limitations = Column(Text, nullable=True)
    source_reference = Column(String(255), nullable=False)
    last_verified_at = Column(DateTime(timezone=True), default=get_utc_now)
    is_demo_rule = Column(Boolean, default=False)
