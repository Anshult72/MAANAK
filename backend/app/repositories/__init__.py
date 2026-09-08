from app.core.config import settings
from app.repositories.in_memory_demo import demo_repository
from app.repositories.neon_postgres import NeonPostgresRepository
from app.core.database import AsyncSessionLocal
from app.core.logging import logger

_neon_repo_instance = None

def get_repository():
    global _neon_repo_instance
    if settings.DATABASE_URL and AsyncSessionLocal is not None and not settings.DEMO_DATA_MODE:
        if _neon_repo_instance is None:
            _neon_repo_instance = NeonPostgresRepository(AsyncSessionLocal)
            logger.info("Using Neon PostgreSQL Repository for data persistence.")
        return _neon_repo_instance
    return demo_repository
