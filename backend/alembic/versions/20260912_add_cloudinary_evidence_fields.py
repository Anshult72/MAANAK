"""Add Cloudinary and SHA-256 integrity fields to evidence table

Revision ID: 20260912_evidence_cloudinary
Revises: None
Create Date: 2026-09-12 11:58:00
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20260912_evidence_cloudinary'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    statements = [
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS evidence_type VARCHAR(50) NOT NULL DEFAULT 'DECLARATION_CROP'",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS cloudinary_public_id VARCHAR(255)",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS cloudinary_secure_url VARCHAR(1000)",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS cloudinary_resource_type VARCHAR(50)",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS cloudinary_format VARCHAR(20)",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS cloudinary_version VARCHAR(50)",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS width INTEGER",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS height INTEGER",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS file_size_bytes INTEGER",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS sha256 VARCHAR(64)",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS etag VARCHAR(100)",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS status VARCHAR(50) NOT NULL DEFAULT 'STORED'",
        "ALTER TABLE evidence ADD COLUMN IF NOT EXISTS created_by VARCHAR(100)",
        "CREATE INDEX IF NOT EXISTS ix_evidence_sha256 ON evidence (sha256)",
    ]
    for stmt in statements:
        op.execute(stmt)


def downgrade() -> None:
    statements = [
        "DROP INDEX IF EXISTS ix_evidence_sha256",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS created_by",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS status",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS etag",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS sha256",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS file_size_bytes",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS height",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS width",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS cloudinary_version",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS cloudinary_format",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS cloudinary_resource_type",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS cloudinary_secure_url",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS cloudinary_public_id",
        "ALTER TABLE evidence DROP COLUMN IF EXISTS evidence_type",
    ]
    for stmt in statements:
        op.execute(stmt)
