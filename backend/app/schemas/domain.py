from datetime import datetime
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, Field

# --- AUTH SCHEMAS ---
class LoginRequest(BaseModel):
    email: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: Dict[str, Any]

class UserResponse(BaseModel):
    id: str
    email: str
    full_name: str
    officer_id: str
    department: str
    role: str
    active: bool

# --- IMAGE & CALIBRATION SCHEMAS ---
class ImageQualityResult(BaseModel):
    quality_score: float
    assessment: str  # GOOD, NEEDS_RETAKE
    reasons: List[str] = []
    blur_score: float
    contrast_score: float
    sharpness_score: float

class ImageResponse(BaseModel):
    id: str
    inspection_id: str
    surface_type: str
    original_path: str
    thumbnail_path: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    quality_assessment: str
    quality_score: Optional[float] = None
    quality_details: Optional[Dict[str, Any]] = None
    created_at: datetime

class KnownDistanceCalibrationInput(BaseModel):
    point1: Dict[str, float]  # {x, y}
    point2: Dict[str, float]  # {x, y}
    known_distance_mm: float
    surface_name: Optional[str] = "FRONT"
    plane_verified: bool = True

class PdpMeasurementInput(BaseModel):
    package_type: str = "RECTANGULAR"  # RECTANGULAR, CYLINDRICAL, OTHER
    package_construction_type: str = "NORMAL"  # NORMAL, BLOWN_FORMED_MOLDED, UNKNOWN
    dimensions_mm: Optional[Dict[str, float]] = None  # {height, width, depth, diameter}
    calibration: Optional[KnownDistanceCalibrationInput] = None
    selected_pdp_bbox: Optional[Dict[str, float]] = None  # {x, y, width, height}

class PdpMeasurementResult(BaseModel):
    pdp_area_cm2: Optional[float] = None
    calibration_status: str  # CALIBRATED, PARTIALLY_CALIBRATED, UNCERTAIN, NOT_CALIBRATED
    pixels_per_mm: Optional[float] = None
    confidence: float
    notes: str

# --- OCR SCHEMAS ---
class BoundingBox(BaseModel):
    x: float
    y: float
    width: float
    height: float

class OcrBlock(BaseModel):
    block_id: str
    text: str
    confidence: float
    bbox: BoundingBox
    image_id: str
    surface_type: str = "FRONT"

class OcrResult(BaseModel):
    raw_text: str
    blocks: List[OcrBlock]
    confidence: float
    image_id: str

# --- STRUCTURED DECLARATIONS SCHEMA ---
class SemanticDeclarationField(BaseModel):
    field_name: str
    value: Optional[str] = None
    normalized_value: Optional[str] = None
    unit: Optional[str] = None
    canonical_unit: Optional[str] = None
    confidence: float = 0.0
    source_block_id: Optional[str] = None
    source_image_id: Optional[str] = None
    source_text: Optional[str] = None
    bbox: Optional[BoundingBox] = None
    provenance: str = "AI_EXTRACTED"  # AI_EXTRACTED, INSPECTOR_VERIFIED, INSPECTOR_ADDED

class ExtractedDeclarationsPayload(BaseModel):
    # Rule 6 Mandatory & Conditional Fields
    commodity_name: Optional[SemanticDeclarationField] = None
    net_quantity: Optional[SemanticDeclarationField] = None
    mrp: Optional[SemanticDeclarationField] = None
    
    # Manufacturer / Packer / Importer semantic separation
    manufacturer_name: Optional[SemanticDeclarationField] = None
    manufacturer_address: Optional[SemanticDeclarationField] = None
    packer_name: Optional[SemanticDeclarationField] = None
    packer_address: Optional[SemanticDeclarationField] = None
    importer_name: Optional[SemanticDeclarationField] = None
    importer_address: Optional[SemanticDeclarationField] = None
    
    # Dates semantic separation
    manufacturing_date: Optional[SemanticDeclarationField] = None
    packing_date: Optional[SemanticDeclarationField] = None
    import_date: Optional[SemanticDeclarationField] = None
    expiry_date: Optional[SemanticDeclarationField] = None
    best_before: Optional[SemanticDeclarationField] = None
    use_by: Optional[SemanticDeclarationField] = None
    
    # Consumer & Others
    consumer_care: Optional[SemanticDeclarationField] = None
    country_of_origin: Optional[SemanticDeclarationField] = None
    dimensions: Optional[SemanticDeclarationField] = None
    unit_sale_price: Optional[SemanticDeclarationField] = None
    
    # Barcode
    barcode: Optional[SemanticDeclarationField] = None

class DeclarationUpdate(BaseModel):
    verified_value: str
    unit: Optional[str] = None
    notes: Optional[str] = None

class DeclarationResponse(BaseModel):
    id: str
    inspection_id: str
    field_name: str
    ai_value: Optional[str] = None
    verified_value: Optional[str] = None
    unit: Optional[str] = None
    confidence: float
    source_image_id: Optional[str] = None
    source_block_id: Optional[str] = None
    source_text: Optional[str] = None
    bbox: Optional[Dict[str, Any]] = None
    presence_status: str
    correctness_status: str
    verification_status: str
    provenance: str
    notes: Optional[str] = None

# --- DECLARATION CORRECTNESS & CONSISTENCY ---
class CorrectnessCheckItem(BaseModel):
    field_name: str
    dimension: str  # PRESENCE, COMPLETENESS, CORRECTNESS, PLACEMENT, LEGIBILITY
    status: str     # PASS, REVIEW, UNVERIFIED, POTENTIAL_VIOLATION
    details: str
    confidence: float
    source_block_id: Optional[str] = None

class CrossFieldConflictItem(BaseModel):
    field_name: str
    issue_type: str  # MULTIPLE_MRPS, INCONSISTENT_QUANTITY, CONFLICTING_ORIGIN, etc.
    description: str
    source_values: List[Dict[str, Any]]  # [{surface: FRONT, value: 399}, {surface: BACK, value: 449}]
    severity: str = "POTENTIAL_ISSUE"

class DeclarationCorrectnessResponse(BaseModel):
    inspection_id: str
    matrix: List[Dict[str, Any]]
    conflicts: List[CrossFieldConflictItem]

# --- RULE APPLICATION CONTEXT ---
class RuleApplicationContextSchema(BaseModel):
    inspectionDate: str
    productCategory: str = "GENERAL"
    countryOfOriginType: str = "DOMESTIC"  # DOMESTIC, IMPORTED
    isImported: bool = False
    inspectionChannel: str = "PHYSICAL"     # PHYSICAL, ECOMMERCE
    packageType: str = "RECTANGULAR"        # RECTANGULAR, CYLINDRICAL, OTHER
    packageConstructionType: str = "NORMAL" # NORMAL, BLOWN_FORMED_MOLDED, UNKNOWN
    commodityType: str = "GENERAL"
    saleChannel: str = "RETAIL"
    isEcommerce: bool = False
    dimensionsRelevant: bool = False
    bestBeforeApplicable: bool = False
    unitSalePriceApplicable: bool = False
    calibrationStatus: str = "NOT_CALIBRATED" # CALIBRATED, PARTIALLY_CALIBRATED, UNCERTAIN, NOT_CALIBRATED
    pdpAreaCm2: Optional[float] = None
    otherApplicableFlags: Dict[str, Any] = {}

# --- COMPLIANCE SCHEMAS ---
class ComplianceCheckResult(BaseModel):
    check_type: str  # MANDATORY_DECLARATION, CHARACTER_HEIGHT, CHARACTER_PROPORTION, READABILITY, PLACEMENT
    field_name: str
    rule_code: str
    rule_version: str
    input_value: Optional[str] = None
    expected_condition: str
    result: str  # PASS, REVIEW, POTENTIAL_VIOLATION, UNVERIFIED
    confidence: float
    explanation: str
    source_reference: str
    evidence_id: Optional[str] = None

class ComplianceAssessmentResponse(BaseModel):
    overall_status: str  # PASS, REVIEW, POTENTIAL_VIOLATION
    score: float         # 0 - 100 analytical assessment score
    score_breakdown: Dict[str, float]
    passed_count: int
    review_count: int
    violation_count: int
    unverified_count: int
    checks: List[ComplianceCheckResult]
    review_items: List[Dict[str, Any]]
    potential_violations: List[Dict[str, Any]]

# --- INSPECTION SCHEMAS ---
class InspectionCreate(BaseModel):
    location: str
    seller_name: Optional[str] = None
    business_name: Optional[str] = None
    product_category: str = "Packaged Food"
    inspection_type: str = "PHYSICAL"  # PHYSICAL, ONLINE_LISTING
    notes: Optional[str] = None

class InspectionUpdate(BaseModel):
    seller_name: Optional[str] = None
    business_name: Optional[str] = None
    notes: Optional[str] = None
    package_type: Optional[str] = None
    package_construction_type: Optional[str] = None

class EvidenceResponse(BaseModel):
    id: str
    inspection_id: str
    image_id: Optional[str] = None
    finding_id: Optional[str] = None
    evidence_type: str = "DECLARATION_CROP"
    original_path: str
    crop_path: Optional[str] = None
    bbox: Optional[Dict[str, Any]] = None
    description: Optional[str] = None
    cloudinary_public_id: Optional[str] = None
    cloudinary_secure_url: Optional[str] = None
    cloudinary_resource_type: Optional[str] = "image"
    cloudinary_format: Optional[str] = None
    thumbnail_url: Optional[str] = None
    width: Optional[int] = None
    height: Optional[int] = None
    file_size_bytes: Optional[int] = None
    sha256: Optional[str] = None
    etag: Optional[str] = None
    status: str = "STORED"
    created_by: Optional[str] = None
    created_at: datetime

class InspectionResponse(BaseModel):
    id: str
    inspection_code: str
    inspector_id: str
    product_id: Optional[str] = None
    inspection_type: str
    inspection_date: datetime
    location: str
    seller_name: Optional[str] = None
    business_name: Optional[str] = None
    status: str
    score: Optional[float] = None
    package_type: Optional[str] = None
    package_construction_type: Optional[str] = None
    calibration_status: Optional[str] = None
    calibration_data: Optional[Dict[str, Any]] = None
    pdp_data: Optional[Dict[str, Any]] = None
    applied_rule_version: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    finalized_at: Optional[datetime] = None
    images: List[ImageResponse] = []
    declarations: List[DeclarationResponse] = []
    evidence_items: List[EvidenceResponse] = []

# --- FINDINGS & VERIFICATION ---
class FindingConfirmRequest(BaseModel):
    inspector_comment: Optional[str] = None

class FindingRejectRequest(BaseModel):
    inspector_comment: Optional[str] = None

class ManualFindingCreate(BaseModel):
    type: str = "MANUAL_OBSERVATION"
    severity: str = "MEDIUM"
    title: str
    description: str
    inspector_comment: Optional[str] = None
    image_id: Optional[str] = None
    bbox: Optional[Dict[str, Any]] = None

class FindingResponse(BaseModel):
    id: str
    inspection_id: str
    compliance_check_id: Optional[str] = None
    type: str
    severity: str
    confidence: float
    status: str  # AI_DETECTED, REVIEW_REQUIRED, CONFIRMED, REJECTED, INSPECTOR_ADDED
    provenance: str
    ai_explanation: Optional[str] = None
    inspector_comment: Optional[str] = None
    confirmed_by: Optional[str] = None
    confirmed_at: Optional[datetime] = None
    created_at: datetime

# --- REPORT SCHEMAS ---
class ReportResponse(BaseModel):
    id: str
    inspection_id: str
    report_version: int
    pdf_path: Optional[str] = None
    pdf_sha256: Optional[str] = None
    docx_path: Optional[str] = None
    docx_sha256: Optional[str] = None
    archival_status: str  # NOT_GENERATED, GENERATING, GENERATED_LOCAL, ARCHIVED, ARCHIVE_FAILED
    generated_by: Optional[str] = None
    created_at: datetime

class InspectionReportModel(BaseModel):
    report_id: str
    report_version: int
    inspection_id: str
    inspection_code: str
    inspection_date: str
    inspector_name: str
    officer_id: str
    location: str
    seller_name: Optional[str]
    business_name: Optional[str]
    inspection_type: str
    
    product_name: str
    brand: Optional[str]
    category: str
    mrp: Optional[str]
    net_quantity: Optional[str]
    
    overall_status: str
    score: float
    
    pdp_area_cm2: Optional[float]
    package_construction: str
    calibration_status: str
    
    declarations: List[Dict[str, Any]]
    compliance_checks: List[Dict[str, Any]]
    findings: List[Dict[str, Any]]
    evidence_images: List[Dict[str, Any]]
    inspector_remarks: Optional[str]
    disclaimer: str
    generated_at: str

# --- FINGERPRINT & LABEL COMPARISON ---
class ProductFingerprintResult(BaseModel):
    product_identity_sha256: str
    canonical_representation: str
    matched_existing_product: bool
    existing_product_id: Optional[str] = None
    match_confidence: float = 0.0

class LabelChangeComparisonResult(BaseModel):
    has_significant_change: bool
    change_type: str  # SEMANTIC_CHANGE, VISUAL_CHANGE, BOTH, NO_SIGNIFICANT_CHANGE
    diff_summary: List[str]
    previous_label_version: Optional[str] = None
    current_label_version: Optional[str] = None
    previous_mrp: Optional[str] = None
    current_mrp: Optional[str] = None
    visual_similarity: float
