import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

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

        # 4. Trigger Analysis
        res = await ac.post(f"/api/inspections/{ins_id}/analyze", headers=headers)
        assert res.status_code == 200
        analysis_data = res.json()
        assert analysis_data["success"] is True
        assert "score" in analysis_data
        assert len(analysis_data["declarations"]) > 0

        # 5. Get Declarations & Edit a field
        dec_id = analysis_data["declarations"][0]["id"]
        res = await ac.patch(f"/api/declarations/{dec_id}", json={
            "verified_value": "ABC Premium Basmati Rice (Verified)",
            "notes": "Inspector physically verified product name"
        }, headers=headers)
        assert res.status_code == 200
        assert res.json()["verified_value"] == "ABC Premium Basmati Rice (Verified)"
        assert res.json()["verification_status"] == "EDITED"

        # 6. Add manual finding
        res = await ac.post(f"/api/inspections/{ins_id}/findings/manual", json={
            "type": "PACKAGE_SEAL_INTEGRITY",
            "severity": "LOW",
            "title": "Minor seam scratch",
            "description": "Outer packaging has a light surface scratch, declarations legible."
        }, headers=headers)
        assert res.status_code == 200
        assert res.json()["provenance"] == "INSPECTOR_ADDED"

        # 7. Finalize inspection
        res = await ac.post(f"/api/inspections/{ins_id}/finalize", headers=headers)
        assert res.status_code == 200
        assert res.json()["success"] is True

        # 8. Generate DOCX report
        res = await ac.post(f"/api/reports/{ins_id}/docx", headers=headers)
        assert res.status_code == 200
        assert res.json()["success"] is True

        # 9. Product Label Comparison
        res = await ac.post("/api/products/prod-rice-01/label-compare", json={
            "current_mrp": "₹499",
            "current_quantity": "5 KG",
            "ocr_summary": "Updated 2026 text"
        }, headers=headers)
        assert res.status_code == 200
        assert res.json()["has_significant_change"] is True

        # 10. Dashboard
        res = await ac.get("/api/dashboard/inspector", headers=headers)
        assert res.status_code == 200
        assert "metrics" in res.json()

        # 11. Audit logs
        res = await ac.get("/api/audit-logs", headers=headers)
        assert res.status_code == 200
        assert len(res.json()) > 0
