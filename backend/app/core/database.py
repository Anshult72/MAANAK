from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.engine import make_url
from sqlalchemy.orm import declarative_base
from app.core.config import settings
from app.core.logging import logger

Base = declarative_base()

engine = None
AsyncSessionLocal = None

if settings.DATABASE_URL:
    try:
        # Neon exposes a standard PostgreSQL URL. SQLAlchemy's async engine
        # needs the asyncpg dialect, so accept either form without requiring
        # users to hand-edit the provider-issued connection string.
        database_url = settings.DATABASE_URL
        if database_url.startswith("postgresql://"):
            database_url = database_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        elif database_url.startswith("postgres://"):
            database_url = database_url.replace("postgres://", "postgresql+asyncpg://", 1)
        # Neon commonly provides connection options intended for libpq.
        # Normalize them to the options accepted by asyncpg.
        parsed_url = make_url(database_url)
        query = dict(parsed_url.query)
        if query.pop("sslmode", None):
            query["ssl"] = "require"
        query.pop("channel_binding", None)
        database_url = parsed_url.set(query=query).render_as_string(hide_password=False)

        # Neon PostgreSQL asyncpg connection
        engine = create_async_engine(
            database_url,
            echo=settings.DEBUG,
            future=True,
            pool_pre_ping=True
        )
        AsyncSessionLocal = async_sessionmaker(
            bind=engine,
            class_=AsyncSession,
            expire_on_commit=False
        )
        logger.info("Initialized Neon PostgreSQL SQLAlchemy async engine.")
    except Exception as e:
        logger.warning(f"Could not connect to configured DATABASE_URL: {e}. Falling back to DEMO_DATA_MODE.")
        engine = None
        AsyncSessionLocal = None
else:
    logger.info("DATABASE_URL not configured. Running in pure DEMO_DATA_MODE with in-memory repository.")

async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    if AsyncSessionLocal is None:
        yield None
        return
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
