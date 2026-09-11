import asyncio
import os
import sys
from datetime import datetime

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__))))

from app.core.config import settings
from app.core.database import Base, engine, AsyncSessionLocal
from app.repositories.in_memory_demo import demo_repository
from app.models.entities import User, Product, Rule, RuleVersion, RuleCoverage, LabelVersion
from app.core.logging import logger


def _as_datetime(value):
    if isinstance(value, str):
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    return value


def _prepare(data, *datetime_fields):
    prepared = dict(data)
    for field in datetime_fields:
        if field in prepared:
            prepared[field] = _as_datetime(prepared[field])
    return prepared

async def seed_neon_database():
    if not settings.DATABASE_URL or engine is None:
        logger.info("DATABASE_URL not configured. In-memory demo repository is active by default.")
        return

    logger.info("Connecting to Neon PostgreSQL and creating tables...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    logger.info("Tables successfully created in Neon PostgreSQL.")

    async with AsyncSessionLocal() as session:
        # Seed users
        for u_data in demo_repository.users.values():
            await session.merge(User(**_prepare(u_data, "created_at")))

        # Seed products
        for p_data in demo_repository.products.values():
            await session.merge(Product(**_prepare(p_data, "created_at", "updated_at")))

        # Seed label versions
        for lv_data in demo_repository.label_versions:
            await session.merge(LabelVersion(**_prepare(lv_data, "captured_at")))

        # Seed authoritative statutory rules, legal documents, versions, amendments, and coverage
        from app.scripts.seed_legal_rules import seed_real_statutory_rules
        await seed_real_statutory_rules(session=session)

        await session.commit()
    logger.info("Seed data successfully committed to Neon PostgreSQL.")

if __name__ == "__main__":
    asyncio.run(seed_neon_database())
