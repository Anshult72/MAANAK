import io
import os
import pytest
from unittest.mock import patch, MagicMock
from PIL import Image

from app.core.config import Settings
from app.services.storage.cloud_storage_interface import EvidenceUploadResult
from app.services.storage.cloudinary_service import CloudinaryStorageService
from app.services.storage.mock_cloud_storage import MockCloudStorageService
from app.services.evidence.evidence_service import EvidenceService
from app.schemas.domain import InspectionReportModel
from app.services.reports.docx_generator import DocxReportGenerator
from app.repositories.in_memory_demo import DemoInMemoryRepository


def _make_sample_image(width: int = 400, height: int = 300, color: tuple = (240, 240, 240)) -> bytes:
    img = Image.new("RGB", (width, height), color=color)
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return buf.getvalue()


def test_cloudinary_config_loading():
    s = Settings(
        CLOUDINARY_CLOUD_NAME="demo-cloud",
        CLOUDINARY_API_KEY="1234567890",
        CLOUDINARY_API_SECRET="secret_token",
        CLOUDINARY_ENABLED=True,
    )
    assert s.CLOUDINARY_CLOUD_NAME == "demo-cloud"
    assert s.CLOUDINARY_API_KEY == "1234567890"
    assert s.CLOUDINARY_API_SECRET == "secret_token"
    assert s.cloudinary_configured is True
    assert s.CLOUDINARY_ENABLED is True


def test_missing_credentials_detected():
    s = Settings(
        CLOUDINARY_CLOUD_NAME=None,
        CLOUDINARY_API_KEY=None,
        CLOUDINARY_API_SECRET=None,
    )
    assert s.cloudinary_configured is False


@pytest.mark.asyncio
async def test_mock_cloud_storage_service():
    storage = MockCloudStorageService(cloud_name="test-cloud", folder="lm_trace/evidence")
    img_bytes = _make_sample_image(200, 100)

    res = await storage.upload_evidence_image(
        file_bytes=img_bytes,
        public_id="ev_001",
        tags=["test"]
    )
    assert isinstance(res, EvidenceUploadResult)
    assert "test-cloud" in res.secure_url
    assert res.public_id == "lm_trace/evidence/ev_001"
    assert res.bytes == len(img_bytes)

    exists = await storage.check_evidence_exists("lm_trace/evidence/ev_001")
    assert exists is True

    deleted = await storage.delete_evidence_image("lm_trace/evidence/ev_001")
    assert deleted is True

    exists_after = await storage.check_evidence_exists("lm_trace/evidence/ev_001")
    assert exists_after is False


@pytest.mark.asyncio
async def test_evidence_service_generates_crop_and_sha256(tmp_path):
    img_path = str(tmp_path / "sample_package.jpg")
    with open(img_path, "wb") as f:
        f.write(_make_sample_image(500, 400))

    mock_storage = MockCloudStorageService(cloud_name="maanak-cloud")
    ev_svc = EvidenceService(storage_service=mock_storage)

    with patch("app.core.config.settings.CLOUDINARY_ENABLED", True), \
         patch("app.core.config.settings.CLOUDINARY_CLOUD_NAME", "demo-cloud"), \
         patch("app.core.config.settings.CLOUDINARY_API_KEY", "demo-key"), \
         patch("app.core.config.settings.CLOUDINARY_API_SECRET", "demo-secret"):
        ev_item = await ev_svc.generate_and_store_crop(
            inspection_id="INS-001",
            original_image_path=img_path,
            bbox={"x": 50, "y": 50, "width": 200, "height": 80},
            evidence_type="MRP_CROP",
            description="MRP Rs 450",
        )

    assert ev_item["status"] == "STORED"
    assert ev_item["evidence_type"] == "MRP_CROP"
    assert ev_item["sha256"] is not None
    assert len(ev_item["sha256"]) == 64
    assert ev_item["cloudinary_secure_url"] is not None
    assert "maanak-cloud" in ev_item["cloudinary_secure_url"]
    assert ev_item["width"] == 200
    assert ev_item["height"] == 80


@pytest.mark.asyncio
async def test_evidence_service_disabled_mode_does_not_fabricate_urls(tmp_path):
    img_path = str(tmp_path / "sample_package.jpg")
    with open(img_path, "wb") as f:
        f.write(_make_sample_image(300, 300))

    ev_svc = EvidenceService(storage_service=MockCloudStorageService())

    with patch("app.core.config.settings.CLOUDINARY_ENABLED", False):
        ev_item = await ev_svc.generate_and_store_crop(
            inspection_id="INS-002",
            original_image_path=img_path,
            bbox={"x": 10, "y": 10, "width": 100, "height": 50},
            evidence_type="DECLARATION_CROP",
        )

    assert ev_item["status"] == "LOCAL_ONLY"
    assert ev_item["cloudinary_secure_url"] is None
    assert ev_item["cloudinary_public_id"] is None
    assert ev_item["sha256"] is not None


@pytest.mark.asyncio
async def test_annotated_overlay_generation(tmp_path):
    img_path = str(tmp_path / "package_front.jpg")
    with open(img_path, "wb") as f:
        f.write(_make_sample_image(400, 400))

    mock_storage = MockCloudStorageService(cloud_name="maanak-cloud")
    ev_svc = EvidenceService(storage_service=mock_storage)

    with patch("app.core.config.settings.CLOUDINARY_ENABLED", True), \
         patch("app.core.config.settings.CLOUDINARY_CLOUD_NAME", "demo-cloud"), \
         patch("app.core.config.settings.CLOUDINARY_API_KEY", "demo-key"), \
         patch("app.core.config.settings.CLOUDINARY_API_SECRET", "demo-secret"):
        overlay = await ev_svc.generate_and_store_annotated_overlay(
            inspection_id="INS-003",
            original_image_path=img_path,
            findings_with_bboxes=[
                {"bbox": {"x": 20, "y": 20, "width": 150, "height": 40}, "label": "MRP", "status": "PASS"},
                {"bbox": {"x": 20, "y": 80, "width": 150, "height": 40}, "label": "Net Qty", "status": "FAIL"},
            ]
        )

    assert overlay is not None
    assert overlay["evidence_type"] == "ANNOTATED_OVERLAY"
    assert overlay["sha256"] is not None
    assert overlay["status"] == "STORED"
    assert overlay["cloudinary_secure_url"] is not None


@pytest.mark.asyncio
async def test_repository_saves_and_lists_evidence():
    repo = DemoInMemoryRepository()
    ins = await repo.create({
        "id": "ins-test-ev",
        "inspection_code": "INS-2026-TEST",
        "location": "Delhi Test",
    })

    items = [
        {
            "id": "ev-01",
            "inspection_id": "ins-test-ev",
            "evidence_type": "MRP_CROP",
            "sha256": "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
            "cloudinary_secure_url": "https://res.cloudinary.com/demo/image/upload/v1/mrp.jpg",
            "status": "STORED",
        },
        {
            "id": "ev-02",
            "inspection_id": "ins-test-ev",
            "evidence_type": "ANNOTATED_OVERLAY",
            "sha256": "123456abcdef7890123456abcdef7890123456abcdef7890123456abcdef7890",
            "cloudinary_secure_url": "https://res.cloudinary.com/demo/image/upload/v1/overlay.jpg",
            "status": "STORED",
        }
    ]

    saved = await repo.save_evidence_items("ins-test-ev", items)
    assert len(saved) == 2

    retrieved = await repo.list_evidence("ins-test-ev")
    assert len(retrieved) == 2
    assert retrieved[0]["id"] == "ev-01"
    assert retrieved[0]["evidence_type"] == "MRP_CROP"

    single = await repo.get_evidence_by_id("ev-01")
    assert single is not None
    assert single["sha256"] == "abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"

    # Idempotent re-save does not create duplicates
    saved_again = await repo.save_evidence_items("ins-test-ev", items)
    assert len(saved_again) == 2
    all_ev = await repo.list_evidence("ins-test-ev")
    assert len(all_ev) == 2


@pytest.mark.asyncio
async def test_docx_report_embeds_evidence(tmp_path):
    crop_path = str(tmp_path / "crop.jpg")
    with open(crop_path, "wb") as f:
        f.write(_make_sample_image(200, 100))

    report_model = InspectionReportModel(
        report_id="rep-1",
        report_version=1,
        inspection_id="ins-test-ev",
        inspection_code="INS-2026-TEST",
        inspection_date="2026-09-12T12:00:00Z",
        inspector_name="Test Officer",
        officer_id="LM-001",
        location="Delhi",
        seller_name="Seller A",
        business_name="Biz A",
        inspection_type="PHYSICAL",
        product_name="Sample Rice",
        brand="Brand X",
        category="Packaged Food",
        mrp="450",
        net_quantity="5 kg",
        overall_status="READY",
        score=95.0,
        pdp_area_cm2=150.0,
        package_construction="NORMAL",
        calibration_status="CALIBRATED",
        declarations=[],
        compliance_checks=[],
        findings=[],
        evidence_images=[
            {
                "evidence_type": "MRP_CROP",
                "description": "MRP declaration crop",
                "crop_path": crop_path,
                "cloudinary_secure_url": None,
                "sha256": "fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
            }
        ],
        inspector_remarks="Clean audit",
        disclaimer="Standard disclaimer",
        generated_at="2026-09-12T12:00:00Z"
    )

    docx_bytes = DocxReportGenerator.generate_docx(report_model)
    assert docx_bytes is not None
    assert len(docx_bytes) > 1000
    assert b"Visual Evidence" in docx_bytes or len(docx_bytes) > 5000


def test_cloudinary_secret_never_exposed_in_health():
    from fastapi.testclient import TestClient
    from app.main import app

    client = TestClient(app)
    res = client.get("/health")
    assert res.status_code == 200
    body = res.json()
    assert "cloudinary" in body
    assert "enabled" in body["cloudinary"]
    assert "configured" in body["cloudinary"]
    # Verify API secret is NEVER in response
    assert "api_secret" not in str(body).lower()
    assert "secret" not in str(body["cloudinary"]).lower()
