from typing import Optional, List, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, or_
from app.repositories.interfaces import (
    IUserRepository, IProductRepository, IInspectionRepository,
    IRuleRepository, IReportRepository, IAuditLogRepository
)
from app.models.entities import (
    User, Product, Inspection, InspectionImage, Declaration, Rule, RuleVersion,
    ComplianceCheck, Violation, Evidence, Report, AuditLog, LabelVersion, RuleCoverage,
    LegalDocument, RuleAmendment, RuleAuditLog
)
from app.core.database import AsyncSessionLocal
import uuid
from datetime import datetime, timezone

def get_now_utc():
    return datetime.now(timezone.utc)

def _parse_dt(val: Any) -> Any:
    if isinstance(val, str):
        try:
            return datetime.fromisoformat(val.replace("Z", "+00:00"))
        except Exception:
            return val
    return val


class NeonPostgresRepository(
    IUserRepository, IProductRepository, IInspectionRepository,
    IRuleRepository, IReportRepository, IAuditLogRepository
):
    def __init__(self, session_factory=AsyncSessionLocal):
        self.session_factory = session_factory

    async def _get_session(self) -> AsyncSession:
        if self.session_factory is None:
            raise RuntimeError("Database session factory is not configured.")
        return self.session_factory()

    # --- IUserRepository ---
    async def get_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(User).where(User.email == email)
            res = await session.execute(stmt)
            user = res.scalar_one_or_none()
            if not user:
                return None
            return {
                "id": user.id, "email": user.email, "full_name": user.full_name,
                "officer_id": user.officer_id, "department": user.department,
                "hashed_password": user.hashed_password, "role": user.role,
                "active": user.active, "created_at": user.created_at.isoformat() if user.created_at else None
            }

    async def _get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(User).where(User.id == user_id)
            res = await session.execute(stmt)
            user = res.scalar_one_or_none()
            if not user:
                return None
            return {
                "id": user.id, "email": user.email, "full_name": user.full_name,
                "officer_id": user.officer_id, "department": user.department,
                "hashed_password": user.hashed_password, "role": user.role,
                "active": user.active, "created_at": user.created_at.isoformat() if user.created_at else None
            }

    async def list_users(self) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(User)
            res = await session.execute(stmt)
            users = res.scalars().all()
            return [
                {
                    "id": u.id, "email": u.email, "full_name": u.full_name,
                    "officer_id": u.officer_id, "department": u.department,
                    "role": u.role, "active": u.active
                } for u in users
            ]

    # --- IProductRepository ---
    async def _get_product_by_id(self, product_id: str) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(Product).where(Product.id == product_id)
            res = await session.execute(stmt)
            p = res.scalar_one_or_none()
            if not p:
                return None
            return {
                "id": p.id, "name": p.name, "brand": p.brand, "category": p.category,
                "manufacturer_name": p.manufacturer_name, "manufacturer_address": p.manufacturer_address,
                "packer_name": p.packer_name, "packer_address": p.packer_address,
                "importer_name": p.importer_name, "importer_address": p.importer_address,
                "net_quantity": p.net_quantity, "net_quantity_unit": p.net_quantity_unit,
                "barcode": p.barcode, "country_of_origin": p.country_of_origin,
                "product_identity_fingerprint": p.product_identity_fingerprint
            }

    async def get_by_fingerprint(self, fingerprint_sha256: str) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(Product).where(Product.product_identity_fingerprint == fingerprint_sha256)
            res = await session.execute(stmt)
            p = res.scalar_one_or_none()
            if not p:
                return None
            return {"id": p.id, "name": p.name, "brand": p.brand, "category": p.category}

    async def list_products(self) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(Product)
            res = await session.execute(stmt)
            products = res.scalars().all()
            return [
                {"id": p.id, "name": p.name, "brand": p.brand, "category": p.category, "barcode": p.barcode}
                for p in products
            ]

    async def create_or_update(self, product_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            p_id = product_data.get("id") or str(uuid.uuid4())
            stmt = select(Product).where(Product.id == p_id)
            res = await session.execute(stmt)
            existing = res.scalar_one_or_none()
            if existing:
                for k, v in product_data.items():
                    if hasattr(existing, k):
                        setattr(existing, k, v)
                existing.updated_at = get_now_utc()
            else:
                new_p = Product(**product_data)
                session.add(new_p)
            await session.commit()
            return product_data

    async def add_label_version(self, label_version_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            lv = LabelVersion(**label_version_data)
            session.add(lv)
            await session.commit()
            return label_version_data

    async def get_label_versions(self, product_id: str) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(LabelVersion).where(LabelVersion.product_id == product_id)
            res = await session.execute(stmt)
            lvs = res.scalars().all()
            return [
                {
                    "id": lv.id, "product_id": lv.product_id, "label_version": lv.label_version,
                    "visual_hash": lv.visual_hash, "ocr_summary": lv.ocr_summary, "mrp": lv.mrp,
                    "net_quantity": lv.net_quantity
                } for lv in lvs
            ]

    # --- IInspectionRepository ---
    async def create(self, inspection_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            clean_data = {}
            for k, v in inspection_data.items():
                if k in ["images", "declarations", "checks", "violations"]:
                    continue
                if k in ["inspection_date", "created_at", "updated_at", "finalized_at"] and isinstance(v, str):
                    clean_data[k] = datetime.fromisoformat(v.replace("Z", "+00:00"))
                else:
                    clean_data[k] = v
            ins = Inspection(**clean_data)
            session.add(ins)
            await session.commit()
            return inspection_data

    async def _get_inspection_by_id(self, inspection_id: str) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(Inspection).where(
                or_(Inspection.id == inspection_id, Inspection.inspection_code == inspection_id)
            )
            res = await session.execute(stmt)
            ins = res.scalar_one_or_none()
            if not ins:
                return None
            actual_id = ins.id
            images = (await session.execute(
                select(InspectionImage).where(InspectionImage.inspection_id == actual_id)
            )).scalars().all()
            declarations = (await session.execute(
                select(Declaration).where(Declaration.inspection_id == actual_id)
            )).scalars().all()
            checks = (await session.execute(
                select(ComplianceCheck).where(ComplianceCheck.inspection_id == actual_id)
            )).scalars().all()
            violations = (await session.execute(
                select(Violation).where(Violation.inspection_id == actual_id)
            )).scalars().all()
            evidence_records = (await session.execute(
                select(Evidence).where(Evidence.inspection_id == actual_id).order_by(Evidence.created_at.asc())
            )).scalars().all()
            return {
                "id": ins.id, "inspection_code": ins.inspection_code, "inspector_id": ins.inspector_id,
                "product_id": ins.product_id, "inspection_type": ins.inspection_type,
                "inspection_date": ins.inspection_date.isoformat() if ins.inspection_date else None,
                "location": ins.location, "seller_name": ins.seller_name, "business_name": ins.business_name,
                "status": ins.status, "score": ins.score, "package_type": ins.package_type,
                "package_construction_type": ins.package_construction_type,
                "calibration_status": ins.calibration_status, "calibration_data": ins.calibration_data,
                "pdp_data": ins.pdp_data, "applied_rule_version": ins.applied_rule_version,
                "rule_snapshot": ins.rule_snapshot, "notes": ins.notes,
                "created_at": ins.created_at.isoformat() if ins.created_at else None,
                "updated_at": ins.updated_at.isoformat() if ins.updated_at else None,
                "finalized_at": ins.finalized_at.isoformat() if ins.finalized_at else None,
                "images": [{
                    "id": image.id, "inspection_id": image.inspection_id,
                    "surface_type": image.surface_type, "original_path": image.original_path,
                    "thumbnail_path": image.thumbnail_path, "width": image.width, "height": image.height,
                    "mime_type": image.mime_type, "file_size": image.file_size,
                    "quality_score": image.quality_score, "quality_assessment": image.quality_assessment,
                    "quality_details": image.quality_details,
                } for image in images],
                "declarations": [{
                    "id": declaration.id, "inspection_id": declaration.inspection_id,
                    "field_name": declaration.field_name, "ai_value": declaration.ai_value,
                    "verified_value": declaration.verified_value, "unit": declaration.unit,
                    "confidence": declaration.confidence, "source_image_id": declaration.source_image_id,
                    "source_block_id": declaration.source_block_id, "source_text": declaration.source_text,
                    "bbox": declaration.bbox, "presence_status": declaration.presence_status,
                    "correctness_status": declaration.correctness_status,
                    "verification_status": declaration.verification_status,
                    "provenance": declaration.provenance, "notes": declaration.notes,
                } for declaration in declarations],
                "checks": [{
                    "id": check.id, "inspection_id": check.inspection_id,
                    "check_type": check.check_type, "field_name": check.field_name,
                    "input_value": check.input_value, "expected_condition": check.expected_condition,
                    "result": check.result, "confidence": check.confidence,
                    "explanation": check.explanation,
                } for check in checks],
                "violations": [{
                    "id": violation.id, "inspection_id": violation.inspection_id,
                    "type": violation.type, "severity": violation.severity,
                    "confidence": violation.confidence, "status": violation.status,
                    "provenance": violation.provenance, "ai_explanation": violation.ai_explanation,
                    "inspector_comment": violation.inspector_comment,
                } for violation in violations],
                "evidence_items": [{
                    "id": ev.id,
                    "inspection_id": ev.inspection_id,
                    "image_id": ev.image_id,
                    "finding_id": ev.finding_id,
                    "evidence_type": ev.evidence_type or "DECLARATION_CROP",
                    "original_path": ev.original_path,
                    "crop_path": ev.crop_path,
                    "bbox": ev.bbox,
                    "description": ev.description,
                    "cloudinary_public_id": ev.cloudinary_public_id,
                    "cloudinary_secure_url": ev.cloudinary_secure_url,
                    "cloudinary_resource_type": ev.cloudinary_resource_type or "image",
                    "cloudinary_format": ev.cloudinary_format,
                    "thumbnail_url": (
                        ev.cloudinary_secure_url.replace("/upload/", "/upload/c_thumb,w_300,h_300/")
                        if ev.cloudinary_secure_url and "/upload/" in ev.cloudinary_secure_url
                        else ev.cloudinary_secure_url
                    ),
                    "width": ev.width,
                    "height": ev.height,
                    "file_size_bytes": ev.file_size_bytes,
                    "sha256": ev.sha256,
                    "etag": ev.etag,
                    "status": ev.status or "STORED",
                    "created_by": ev.created_by,
                    "created_at": ev.created_at.isoformat() if ev.created_at else None,
                } for ev in evidence_records],
            }

    async def get_by_id(self, entity_id: str) -> Optional[Dict[str, Any]]:
        """Resolve the shared legacy repository method without method overwrites."""
        if entity_id.startswith("u-"):
            return await self._get_user_by_id(entity_id)
        if entity_id.startswith("prod-"):
            return await self._get_product_by_id(entity_id)
        return await self._get_inspection_by_id(entity_id)

    async def update(self, inspection_id: str, updates: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = update(Inspection).where(Inspection.id == inspection_id).values(**updates)
            await session.execute(stmt)
            await session.commit()
            return await self._get_inspection_by_id(inspection_id)

    async def list_inspections(self, inspector_id: Optional[str] = None, status: Optional[str] = None, query: Optional[str] = None) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(Inspection)
            if inspector_id:
                stmt = stmt.where(or_(Inspection.inspector_id == inspector_id, Inspection.inspector_id.is_(None)))
            if status:
                stmt = stmt.where(Inspection.status == status)
            if query:
                stmt = stmt.where(or_(
                    Inspection.inspection_code.ilike(f"%{query}%"),
                    Inspection.seller_name.ilike(f"%{query}%"),
                    Inspection.business_name.ilike(f"%{query}%"),
                    Inspection.location.ilike(f"%{query}%"),
                ))
            stmt = stmt.order_by(Inspection.created_at.desc(), Inspection.inspection_date.desc())
            res = await session.execute(stmt)
            inspections = res.scalars().all()
            return [
                {
                    "id": ins.id, "inspection_code": ins.inspection_code, "status": ins.status,
                    "inspector_id": ins.inspector_id,
                    "inspection_type": ins.inspection_type, "location": ins.location,
                    "seller_name": ins.seller_name, "business_name": ins.business_name,
                    "score": ins.score,
                    "inspection_date": ins.inspection_date.isoformat() if ins.inspection_date else None,
                    "created_at": ins.created_at.isoformat() if ins.created_at else None,
                } for ins in inspections
            ]

    async def add_image(self, inspection_id: str, image_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            img = InspectionImage(**image_data)
            session.add(img)
            await session.commit()
            return image_data

    async def delete_image(self, inspection_id: str, image_id: str) -> bool:
        async with await self._get_session() as session:
            stmt = delete(InspectionImage).where(InspectionImage.id == image_id, InspectionImage.inspection_id == inspection_id)
            res = await session.execute(stmt)
            await session.commit()
            return res.rowcount > 0

    async def save_declarations(self, inspection_id: str, declarations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            await session.execute(delete(Declaration).where(Declaration.inspection_id == inspection_id))
            for dec_data in declarations:
                dec = Declaration(**dec_data)
                session.add(dec)
            await session.commit()
            return declarations

    async def update_declaration(self, declaration_id: str, updates: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = update(Declaration).where(Declaration.id == declaration_id).values(**updates)
            await session.execute(stmt)
            await session.commit()
            return updates

    async def save_compliance_results(self, inspection_id: str, checks: List[Dict[str, Any]], violations: List[Dict[str, Any]]) -> None:
        async with await self._get_session() as session:
            await session.execute(delete(Violation).where(Violation.inspection_id == inspection_id))
            await session.execute(delete(ComplianceCheck).where(ComplianceCheck.inspection_id == inspection_id))
            for c in checks:
                if not isinstance(c, dict):
                    continue
                check_data = {
                    "id": c.get("id") or str(uuid.uuid4()),
                    "inspection_id": c.get("inspection_id") or inspection_id,
                    "rule_version_id": c.get("rule_version_id"),
                    "check_type": c.get("check_type") or c.get("rule_code") or "GENERAL",
                    "field_name": c.get("field_name") or "general",
                    "input_value": c.get("input_value"),
                    "expected_condition": c.get("expected_condition"),
                    "result": c.get("result", "PASS"),
                    "confidence": float(c.get("confidence", 1.0)),
                    "explanation": c.get("explanation", ""),
                    "evidence_id": c.get("evidence_id")
                }
                session.add(ComplianceCheck(**check_data))
            for v in violations:
                if not isinstance(v, dict):
                    continue
                viol_data = {
                    "id": v.get("id") or str(uuid.uuid4()),
                    "inspection_id": v.get("inspection_id") or inspection_id,
                    "compliance_check_id": v.get("compliance_check_id"),
                    "type": v.get("type", "UNKNOWN"),
                    "severity": v.get("severity", "MEDIUM"),
                    "confidence": float(v.get("confidence", 1.0)),
                    "status": v.get("status", "AI_DETECTED"),
                    "provenance": v.get("provenance", "AI_DETECTED"),
                    "ai_explanation": v.get("ai_explanation"),
                    "inspector_comment": v.get("inspector_comment")
                }
                session.add(Violation(**viol_data))
            await session.commit()

    async def update_finding(self, finding_id: str, updates: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = update(Violation).where(Violation.id == finding_id).values(**updates)
            await session.execute(stmt)
            await session.commit()
            return updates

    async def finalize_inspection(self, inspection_id: str, snapshot_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            stmt = update(Inspection).where(Inspection.id == inspection_id).values(
                status="FINALIZED", finalized_at=get_now_utc(), rule_snapshot=snapshot_data
            )
            await session.execute(stmt)
            await session.commit()
            return await self._get_inspection_by_id(inspection_id)

    async def save_evidence_items(self, inspection_id: str, evidence_items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            saved_results = []
            for item in evidence_items:
                ev_id = item.get("id") or str(uuid.uuid4())
                stmt = select(Evidence).where(Evidence.id == ev_id)
                res = await session.execute(stmt)
                existing = res.scalar_one_or_none()

                clean_data = {
                    "id": ev_id,
                    "inspection_id": item.get("inspection_id") or inspection_id,
                    "image_id": item.get("image_id"),
                    "finding_id": item.get("finding_id"),
                    "evidence_type": item.get("evidence_type") or "DECLARATION_CROP",
                    "original_path": item.get("original_path") or "",
                    "crop_path": item.get("crop_path"),
                    "bbox": item.get("bbox"),
                    "description": item.get("description"),
                    "cloudinary_public_id": item.get("cloudinary_public_id"),
                    "cloudinary_secure_url": item.get("cloudinary_secure_url"),
                    "cloudinary_resource_type": item.get("cloudinary_resource_type") or "image",
                    "cloudinary_format": item.get("cloudinary_format"),
                    "cloudinary_version": item.get("cloudinary_version"),
                    "width": item.get("width"),
                    "height": item.get("height"),
                    "file_size_bytes": item.get("file_size_bytes"),
                    "sha256": item.get("sha256"),
                    "etag": item.get("etag"),
                    "status": item.get("status") or "STORED",
                    "created_by": item.get("created_by"),
                }

                if existing:
                    # Update fields if not immutable
                    for k, v in clean_data.items():
                        if k != "id" and hasattr(existing, k):
                            setattr(existing, k, v)
                else:
                    new_ev = Evidence(**clean_data)
                    session.add(new_ev)

                saved_results.append(clean_data)

            await session.commit()
            return saved_results

    async def list_evidence(self, inspection_id: str) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(Evidence).where(Evidence.inspection_id == inspection_id).order_by(Evidence.created_at.asc())
            res = await session.execute(stmt)
            records = res.scalars().all()
            return [{
                "id": ev.id,
                "inspection_id": ev.inspection_id,
                "image_id": ev.image_id,
                "finding_id": ev.finding_id,
                "evidence_type": ev.evidence_type or "DECLARATION_CROP",
                "original_path": ev.original_path,
                "crop_path": ev.crop_path,
                "bbox": ev.bbox,
                "description": ev.description,
                "cloudinary_public_id": ev.cloudinary_public_id,
                "cloudinary_secure_url": ev.cloudinary_secure_url,
                "cloudinary_resource_type": ev.cloudinary_resource_type or "image",
                "cloudinary_format": ev.cloudinary_format,
                "thumbnail_url": (
                    ev.cloudinary_secure_url.replace("/upload/", "/upload/c_thumb,w_300,h_300/")
                    if ev.cloudinary_secure_url and "/upload/" in ev.cloudinary_secure_url
                    else ev.cloudinary_secure_url
                ),
                "width": ev.width,
                "height": ev.height,
                "file_size_bytes": ev.file_size_bytes,
                "sha256": ev.sha256,
                "etag": ev.etag,
                "status": ev.status or "STORED",
                "created_by": ev.created_by,
                "created_at": ev.created_at.isoformat() if ev.created_at else None,
            } for ev in records]

    async def get_evidence_by_id(self, evidence_id: str) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(Evidence).where(Evidence.id == evidence_id)
            res = await session.execute(stmt)
            ev = res.scalar_one_or_none()
            if not ev:
                return None
            return {
                "id": ev.id,
                "inspection_id": ev.inspection_id,
                "image_id": ev.image_id,
                "finding_id": ev.finding_id,
                "evidence_type": ev.evidence_type or "DECLARATION_CROP",
                "original_path": ev.original_path,
                "crop_path": ev.crop_path,
                "bbox": ev.bbox,
                "description": ev.description,
                "cloudinary_public_id": ev.cloudinary_public_id,
                "cloudinary_secure_url": ev.cloudinary_secure_url,
                "cloudinary_resource_type": ev.cloudinary_resource_type or "image",
                "cloudinary_format": ev.cloudinary_format,
                "thumbnail_url": (
                    ev.cloudinary_secure_url.replace("/upload/", "/upload/c_thumb,w_300,h_300/")
                    if ev.cloudinary_secure_url and "/upload/" in ev.cloudinary_secure_url
                    else ev.cloudinary_secure_url
                ),
                "width": ev.width,
                "height": ev.height,
                "file_size_bytes": ev.file_size_bytes,
                "sha256": ev.sha256,
                "etag": ev.etag,
                "status": ev.status or "STORED",
                "created_by": ev.created_by,
                "created_at": ev.created_at.isoformat() if ev.created_at else None,
            }

    async def update_evidence(self, evidence_id: str, updates: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = update(Evidence).where(Evidence.id == evidence_id).values(**updates)
            await session.execute(stmt)
            await session.commit()
            return await self.get_evidence_by_id(evidence_id)

    # --- IRuleRepository ---
    async def list_rules(self, category: Optional[str] = None, active_only: bool = True) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(Rule)
            if active_only:
                stmt = stmt.where(Rule.active == True)
            if category and category.upper() != "ALL":
                # Support user-friendly categories and DB enum values
                norm_cat = category.strip().upper().replace(" ", "_").replace("/", "_")
                if "DECLARATION" in norm_cat:
                    stmt = stmt.where(Rule.category == "DECLARATIONS")
                elif "PDP" in norm_cat or "FONT" in norm_cat:
                    stmt = stmt.where(Rule.category == "PDP_FONT_SIZE")
                elif "MRP" in norm_cat:
                    stmt = stmt.where(Rule.category == "MRP")
                elif "ECOM" in norm_cat or "E_COMMERCE" in norm_cat:
                    stmt = stmt.where(Rule.category == "E_COMMERCE")
                elif "OTHER" in norm_cat:
                    stmt = stmt.where(Rule.category.notin_(["DECLARATIONS", "PDP_FONT_SIZE", "MRP", "E_COMMERCE"]))
                else:
                    stmt = stmt.where(Rule.category == norm_cat)

            res = await session.execute(stmt)
            rules = res.scalars().all()
            
            output = []
            for r in rules:
                # Retrieve current active version
                v_stmt = select(RuleVersion).where(RuleVersion.rule_id == r.id).order_by(RuleVersion.effective_from.desc())
                v_res = await session.execute(v_stmt)
                all_v = v_res.scalars().all()
                latest_v = all_v[0] if all_v else None

                output.append({
                    "id": r.id,
                    "code": r.code,
                    "statutory_reference": r.statutory_reference or "Legal Metrology Rules, 2011",
                    "title": r.title,
                    "description": r.description,
                    "category": r.category,
                    "validation_type": r.validation_type,
                    "coverage_status": r.coverage_status or "FULLY_IMPLEMENTED",
                    "parameters": r.parameters_json or {},
                    "evidence_requirements": r.evidence_requirements_json or [],
                    "active": r.active,
                    "current_version": latest_v.version if latest_v else "1.0",
                    "current_version_id": latest_v.id if latest_v else None,
                    "status": latest_v.status if latest_v else ("ACTIVE" if r.active else "INACTIVE"),
                    "effective_from": latest_v.effective_from.isoformat() if latest_v and latest_v.effective_from else None,
                    "effective_to": latest_v.effective_to.isoformat() if latest_v and latest_v.effective_to else None,
                    "source_name": latest_v.source_name if latest_v else "Department of Consumer Affairs",
                    "source_reference": latest_v.source_reference if latest_v else (r.statutory_reference or "LM Rules 2011"),
                    "source_url": latest_v.source_url if latest_v else "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                    "versions_count": len(all_v)
                })
            return output

    async def get_rule_by_id(self, rule_id: str) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(Rule).where(or_(Rule.id == rule_id, Rule.code == rule_id))
            res = await session.execute(stmt)
            r = res.scalar_one_or_none()
            if not r:
                return None
            
            v_stmt = select(RuleVersion).where(RuleVersion.rule_id == r.id).order_by(RuleVersion.effective_from.desc())
            v_res = await session.execute(v_stmt)
            versions = v_res.scalars().all()
            latest_v = versions[0] if versions else None

            a_stmt = select(RuleAmendment).where(RuleAmendment.rule_id == r.id).order_by(RuleAmendment.effective_from.desc())
            a_res = await session.execute(a_stmt)
            amendments = a_res.scalars().all()

            return {
                "id": r.id,
                "code": r.code,
                "statutory_reference": r.statutory_reference or "Legal Metrology Rules, 2011",
                "title": r.title,
                "description": r.description,
                "category": r.category,
                "validation_type": r.validation_type,
                "coverage_status": r.coverage_status or "FULLY_IMPLEMENTED",
                "parameters": r.parameters_json or {},
                "evidence_requirements": r.evidence_requirements_json or [],
                "active": r.active,
                "current_version": latest_v.version if latest_v else "1.0",
                "status": latest_v.status if latest_v else ("ACTIVE" if r.active else "INACTIVE"),
                "effective_from": latest_v.effective_from.isoformat() if latest_v and latest_v.effective_from else None,
                "effective_to": latest_v.effective_to.isoformat() if latest_v and latest_v.effective_to else None,
                "source_name": latest_v.source_name if latest_v else "Department of Consumer Affairs",
                "source_reference": latest_v.source_reference if latest_v else (r.statutory_reference or "LM Rules 2011"),
                "source_url": latest_v.source_url if latest_v else "https://consumeraffairs.gov.in/pages/legal-metrology-act",
                "versions": [
                    {
                        "id": v.id,
                        "rule_id": v.rule_id,
                        "version": v.version,
                        "version_label": v.version_label or f"Version {v.version}",
                        "description": v.description,
                        "conditions": v.conditions,
                        "thresholds": v.thresholds,
                        "severity": v.severity,
                        "status": v.status,
                        "source_name": v.source_name,
                        "source_reference": v.source_reference,
                        "source_url": v.source_url,
                        "source_document_id": v.source_document_id,
                        "publication_date": v.publication_date.isoformat() if v.publication_date else None,
                        "effective_from": v.effective_from.isoformat() if v.effective_from else None,
                        "effective_to": v.effective_to.isoformat() if v.effective_to else None,
                        "approved_by": v.approved_by,
                        "approved_at": v.approved_at.isoformat() if v.approved_at else None,
                    } for v in versions
                ],
                "amendments": [
                    {
                        "id": a.id,
                        "previous_version_id": a.previous_version_id,
                        "new_version_id": a.new_version_id,
                        "amendment_type": a.amendment_type,
                        "amendment_summary": a.amendment_summary,
                        "source_document_id": a.source_document_id,
                        "effective_from": a.effective_from.isoformat() if a.effective_from else None,
                    } for a in amendments
                ]
            }

    async def get_active_versions_for_date(self, inspection_date_iso: str) -> List[Dict[str, Any]]:
        dt = _parse_dt(inspection_date_iso)
        if isinstance(dt, str):
            dt = datetime.fromisoformat(dt.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)

        async with await self._get_session() as session:
            stmt = (
                select(RuleVersion, Rule)
                .join(Rule, RuleVersion.rule_id == Rule.id)
                .where(
                    Rule.active == True,
                    RuleVersion.effective_from <= dt,
                    or_(RuleVersion.effective_to == None, RuleVersion.effective_to > dt),
                    RuleVersion.status.in_(["ACTIVE", "APPROVED", "SCHEDULED"])
                )
            )
            res = await session.execute(stmt)
            pairs = res.all()
            
            output = []
            for v, r in pairs:
                output.append({
                    "id": v.id,
                    "rule_id": v.rule_id,
                    "rule_code": r.code,
                    "rule_title": r.title,
                    "rule_category": r.category,
                    "statutory_reference": r.statutory_reference or v.source_reference,
                    "validation_type": r.validation_type,
                    "parameters": r.parameters_json or {},
                    "evidence_requirements": r.evidence_requirements_json or [],
                    "coverage_status": r.coverage_status or "FULLY_IMPLEMENTED",
                    "version": v.version,
                    "version_label": v.version_label or f"Version {v.version}",
                    "conditions": v.conditions,
                    "thresholds": v.thresholds,
                    "severity": v.severity,
                    "status": v.status,
                    "source_name": v.source_name,
                    "source_reference": v.source_reference,
                    "source_url": v.source_url,
                    "effective_from": v.effective_from.isoformat() if v.effective_from else None,
                    "effective_to": v.effective_to.isoformat() if v.effective_to else None,
                    "is_demo_rule": v.is_demo_rule
                })
            return output

    async def create_rule(self, rule_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            clean_data = dict(rule_data)
            for dt_col in ["created_at", "updated_at"]:
                if dt_col in clean_data:
                    clean_data[dt_col] = _parse_dt(clean_data[dt_col])
            clean_data = {k: v for k, v in clean_data.items() if k not in ["versions", "amendments"]}
            r = Rule(**clean_data)
            session.add(r)
            await session.commit()
            return rule_data

    async def create_version(self, rule_id: str, version_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            clean_data = dict(version_data)
            clean_data["rule_id"] = rule_id
            for dt_col in ["effective_from", "effective_to", "publication_date", "approved_at", "created_at"]:
                if dt_col in clean_data and clean_data[dt_col]:
                    clean_data[dt_col] = _parse_dt(clean_data[dt_col])
            v = RuleVersion(**clean_data)
            session.add(v)
            await session.commit()
            return version_data

    async def list_rule_versions(self, rule_id: str) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(RuleVersion).where(or_(RuleVersion.rule_id == rule_id, RuleVersion.id == rule_id)).order_by(RuleVersion.effective_from.desc())
            res = await session.execute(stmt)
            versions = res.scalars().all()
            return [
                {
                    "id": v.id, "rule_id": v.rule_id, "version": v.version,
                    "version_label": v.version_label, "description": v.description,
                    "conditions": v.conditions, "thresholds": v.thresholds,
                    "severity": v.severity, "status": v.status,
                    "source_name": v.source_name, "source_reference": v.source_reference,
                    "source_url": v.source_url,
                    "effective_from": v.effective_from.isoformat() if v.effective_from else None,
                    "effective_to": v.effective_to.isoformat() if v.effective_to else None,
                } for v in versions
            ]

    async def list_rule_amendments(self, rule_id: str) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(RuleAmendment).where(RuleAmendment.rule_id == rule_id).order_by(RuleAmendment.effective_from.desc())
            res = await session.execute(stmt)
            amendments = res.scalars().all()
            return [
                {
                    "id": a.id, "rule_id": a.rule_id, "previous_version_id": a.previous_version_id,
                    "new_version_id": a.new_version_id, "amendment_type": a.amendment_type,
                    "amendment_summary": a.amendment_summary, "source_document_id": a.source_document_id,
                    "effective_from": a.effective_from.isoformat() if a.effective_from else None,
                } for a in amendments
            ]

    async def approve_rule_version(self, rule_id: str, version_id: str, approved_by: str) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(RuleVersion).where(RuleVersion.id == version_id)
            res = await session.execute(stmt)
            v = res.scalar_one_or_none()
            if not v:
                return None
            
            now_utc = get_now_utc()
            is_future = v.effective_from and v.effective_from > now_utc
            v.status = "SCHEDULED" if is_future else "ACTIVE"
            v.approved_by = approved_by
            v.approved_at = now_utc
            await session.commit()
            return {
                "id": v.id, "rule_id": v.rule_id, "version": v.version,
                "status": v.status, "approved_by": v.approved_by,
                "approved_at": v.approved_at.isoformat() if v.approved_at else None
            }

    async def list_legal_documents(self) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(LegalDocument).order_by(LegalDocument.effective_date.desc())
            res = await session.execute(stmt)
            docs = res.scalars().all()
            return [
                {
                    "id": d.id, "title": d.title, "document_type": d.document_type,
                    "source_url": d.source_url, "source_authority": d.source_authority,
                    "notification_number": d.notification_number,
                    "publication_date": d.publication_date.isoformat() if d.publication_date else None,
                    "effective_date": d.effective_date.isoformat() if d.effective_date else None,
                    "document_hash": d.document_hash, "document_version": d.document_version,
                    "status": d.status
                } for d in docs
            ]

    async def save_legal_document(self, doc_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            clean_data = dict(doc_data)
            for dt_col in ["publication_date", "effective_date", "created_at"]:
                if dt_col in clean_data and clean_data[dt_col]:
                    clean_data[dt_col] = _parse_dt(clean_data[dt_col])
            
            stmt = select(LegalDocument).where(LegalDocument.id == clean_data["id"])
            res = await session.execute(stmt)
            existing = res.scalar_one_or_none()
            if existing:
                for k, v in clean_data.items():
                    if hasattr(existing, k):
                        setattr(existing, k, v)
            else:
                d = LegalDocument(**clean_data)
                session.add(d)
            await session.commit()
            return doc_data

    async def save_amendment(self, amendment_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            clean_data = dict(amendment_data)
            for dt_col in ["effective_from", "created_at"]:
                if dt_col in clean_data and clean_data[dt_col]:
                    clean_data[dt_col] = _parse_dt(clean_data[dt_col])
            stmt = select(RuleAmendment).where(RuleAmendment.id == clean_data.get("id"))
            res = await session.execute(stmt)
            existing = res.scalar_one_or_none()
            if existing:
                for k, v in clean_data.items():
                    if hasattr(existing, k):
                        setattr(existing, k, v)
            else:
                a = RuleAmendment(**clean_data)
                session.add(a)
            await session.commit()
            return amendment_data

    async def save_rule_audit_log(self, audit_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            clean_data = dict(audit_data)
            if "timestamp" in clean_data and clean_data["timestamp"]:
                clean_data["timestamp"] = _parse_dt(clean_data["timestamp"])
            log = RuleAuditLog(**clean_data)
            session.add(log)
            await session.commit()
            return audit_data

    async def get_rule_coverage(self) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(RuleCoverage)
            res = await session.execute(stmt)
            covs = res.scalars().all()
            return [
                {
                    "id": c.id, "rule_family": c.rule_family, "rule_codes": c.rule_codes,
                    "coverage_status": c.coverage_status, "supported_checks": c.supported_checks,
                    "limitations": c.limitations,
                    "source_reference": c.source_reference
                } for c in covs
            ]

    # --- IReportRepository ---
    async def save_report_metadata(self, report_data: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            clean_data = dict(report_data)
            for dt_col in ["pdf_generated_at", "docx_generated_at", "created_at"]:
                if dt_col in clean_data:
                    clean_data[dt_col] = _parse_dt(clean_data[dt_col])
            
            stmt = select(Report).where(Report.inspection_id == clean_data["inspection_id"])
            res = await session.execute(stmt)
            existing = res.scalar_one_or_none()
            if existing:
                for k, v in clean_data.items():
                    if hasattr(existing, k):
                        setattr(existing, k, v)
            else:
                rep = Report(**clean_data)
                session.add(rep)
            await session.commit()
            return report_data

    async def get_report_by_inspection_id(self, inspection_id: str) -> Optional[Dict[str, Any]]:
        async with await self._get_session() as session:
            ins = await self._get_inspection_by_id(inspection_id)
            canonical_id = ins["id"] if ins else inspection_id
            stmt = select(Report).where(
                or_(Report.inspection_id == canonical_id, Report.inspection_id == inspection_id)
            )
            res = await session.execute(stmt)
            rep = res.scalar_one_or_none()
            if not rep:
                return None
            return {
                "id": rep.id, "inspection_id": rep.inspection_id, "report_version": rep.report_version,
                "pdf_path": rep.pdf_path, "pdf_sha256": rep.pdf_sha256,
                "docx_path": rep.docx_path, "docx_sha256": rep.docx_sha256,
                "archival_status": rep.archival_status
            }

    # --- IAuditLogRepository ---
    async def append_log(self, log_entry: Dict[str, Any]) -> Dict[str, Any]:
        async with await self._get_session() as session:
            clean_log = dict(log_entry)
            if "timestamp" in clean_log:
                clean_log["timestamp"] = _parse_dt(clean_log["timestamp"])
            al = AuditLog(**clean_log)
            session.add(al)
            await session.commit()
            return log_entry

    async def list_logs(self, limit: int = 100) -> List[Dict[str, Any]]:
        async with await self._get_session() as session:
            stmt = select(AuditLog).order_by(AuditLog.timestamp.desc()).limit(limit)
            res = await session.execute(stmt)
            logs = res.scalars().all()
            return [
                {
                    "id": l.id, "user_id": l.user_id, "role": l.role, "action": l.action,
                    "resource_type": l.resource_type, "timestamp": l.timestamp.isoformat() if l.timestamp else None
                } for l in logs
            ]
