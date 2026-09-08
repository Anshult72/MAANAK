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

        # Seed rules
        for r_data in demo_repository.rules.values():
            r_dict = {k: v for k, v in r_data.items() if k != "versions"}
            await session.merge(Rule(**_prepare(r_dict, "created_at", "updated_at")))
            for v_data in r_data.get("versions", []):
                v_dict = {k: v for k, v in v_data.items() if k != "rule_code" and k != "rule_title" and k != "rule_category"}
                await session.merge(RuleVersion(**_prepare(v_dict, "effective_from", "effective_to", "created_at")))

        # Seed coverage
        for cov_data in demo_repository.rule_coverage:
            await session.merge(RuleCoverage(**_prepare(cov_data, "last_verified_at")))

        # Seed label versions
        for lv_data in demo_repository.label_versions:
            await session.merge(LabelVersion(**_prepare(lv_data, "captured_at")))

        await session.commit()
    logger.info("Seed data successfully committed to Neon PostgreSQL.")

if __name__ == "__main__":
    asyncio.run(seed_neon_database())
