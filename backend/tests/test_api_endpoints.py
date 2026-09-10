import io
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

def _make_sample_png_bytes() -> bytes:
    from PIL import Image, ImageDraw
    img = Image.new('RGB', (350, 180), color=(255, 255, 255))
    d = ImageDraw.Draw(img)
    d.text((15, 15), "ABC Premium Basmati Rice", fill=(0, 0, 0))
    d.text((15, 50), "Net Qty: 5 kg", fill=(0, 0, 0))
    d.text((15, 85), "MRP Rs 450.00 (Incl. all taxes)", fill=(0, 0, 0))
    d.text((15, 120), "Packed on: 08/2026", fill=(0, 0, 0))
    d.text((15, 150), "Consumer Care: 1800-111-2222", fill=(0, 0, 0))
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    return buf.getvalue()

_SAMPLE_PNG = _make_sample_png_bytes()

@pytest.mark.asyncio
async def test_full_api_workflow():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        # 1. Health check
        res = await ac.get("/health")
        assert res.status_code == 200
        assert res.json()["status"] == "healthy"

        # 2. Login
        res = await ac.post("/api/auth/login", json={
            "email": "inspector@demo.gov.in",
            "password": "Inspector@123"
        })
        assert res.status_code == 200
        token = res.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 3. Create Inspection
        res = await ac.post("/api/inspections", json={
            "location": "Lucknow Market",
            "seller_name": "Sharma Stores",
            "business_name": "Sharma Retail",
            "product_category": "Packaged Food",
            "inspection_type": "PHYSICAL",
            "notes": "Test automated inspection"
        }, headers=headers)
        assert res.status_code == 200
        ins_id = res.json()["id"]
        assert "INS-2026-" in res.json()["inspection_code"]

        # 4. Upload a package surface image (analyze requires >= 1 image)
        res = await ac.post(
            f"/api/inspections/{ins_id}/images",
            headers=headers,
            files={"file": ("front.png", io.BytesIO(_SAMPLE_PNG), "image/png")},
            data={"surface_type": "FRONT"},
        )
        assert res.status_code == 200
        assert res.json()["surface_type"] == "FRONT"

        # 5. Trigger Analysis
        res = await ac.post(f"/api/inspections/{ins_id}/analyze", headers=headers)
        assert res.status_code == 200
        analysis_data = res.json()
        assert analysis_data["success"] is True
        assert "score" in analysis_data
        assert len(analysis_data["declarations"]) > 0

        # 6. Get Declarations & Edit a field
        dec_id = analysis_data["declarations"][0]["id"]
        res = await ac.patch(f"/api/declarations/{dec_id}", json={
            "verified_value": "ABC Premium Basmati Rice (Verified)",
            "notes": "Inspector physically verified product name"
        }, headers=headers)
        assert res.status_code == 200
        assert res.json()["verified_value"] == "ABC Premium Basmati Rice (Verified)"
        assert res.json()["verification_status"] == "EDITED"

        # 7. Add manual finding
        res = await ac.post(f"/api/inspections/{ins_id}/findings/manual", json={
            "type": "PACKAGE_SEAL_INTEGRITY",
            "severity": "LOW",
            "title": "Minor seam scratch",
            "description": "Outer packaging has a light surface scratch, declarations legible."
        }, headers=headers)
        assert res.status_code == 200
        assert res.json()["provenance"] == "INSPECTOR_ADDED"

        # 8. Finalize inspection
        res = await ac.post(f"/api/inspections/{ins_id}/finalize", headers=headers)
        assert res.status_code == 200
        assert res.json()["success"] is True

        # 9. Generate DOCX report
        res = await ac.post(f"/api/reports/{ins_id}/docx", headers=headers)
        assert res.status_code == 200
        assert res.json()["success"] is True

        # 10. Product Label Comparison
        res = await ac.post("/api/products/prod-rice-01/label-compare", json={
            "current_mrp": "₹499",
            "current_quantity": "5 KG",
            "ocr_summary": "Updated 2026 text"
        }, headers=headers)
        assert res.status_code == 200
        assert res.json()["has_significant_change"] is True

        # 11. Dashboard
        res = await ac.get("/api/dashboard/inspector", headers=headers)
        assert res.status_code == 200
        assert "metrics" in res.json()

        # 12. Audit logs
        res = await ac.get("/api/audit-logs", headers=headers)
        assert res.status_code == 200
        assert len(res.json()) > 0
