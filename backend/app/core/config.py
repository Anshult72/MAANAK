import os
from typing import List, Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field

class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    APP_NAME: str = "MAANAK - Legal Metrology Platform"
    APP_ENV: str = "development"
    DEBUG: bool = True
    
    # Neon PostgreSQL connection string (postgresql+asyncpg://...)
    # If empty, DEMO_DATA_MODE is activated (in-memory repository, zero credentials needed)
    DATABASE_URL: Optional[str] = Field(default=None, validation_alias="DATABASE_URL")
    DEMO_DATA_MODE: bool = Field(default=True, validation_alias="DEMO_DATA_MODE")
    
    # Security
    JWT_SECRET: str = Field(default="maanak-super-secret-jwt-key-sih-2026-prototype", validation_alias="JWT_SECRET")
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 hours
    
    # Groq AI: vision OCR and text normalization use separate configurable models.
    GROQ_API_KEY: Optional[str] = Field(default=None, validation_alias="GROQ_API_KEY")
    GROQ_VISION_MODEL: str = Field(default="qwen/qwen3.8-27b", validation_alias="GROQ_VISION_MODEL")
    GROQ_TEXT_MODEL: str = Field(default="openai/gpt-oss-20b", validation_alias="GROQ_TEXT_MODEL")
    MOCK_AI_MODE: bool = Field(default=True, validation_alias="MOCK_AI_MODE")
    
    # Local server-side prototype storage
    STORAGE_ROOT: str = Field(default="storage", validation_alias="STORAGE_ROOT")
    
    # CORS
    CORS_ORIGINS: str = "*"

    @property
    def cors_origins_list(self) -> List[str]:
        if self.CORS_ORIGINS == "*":
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def is_demo_mode(self) -> bool:
        return not self.DATABASE_URL or self.DEMO_DATA_MODE

settings = Settings()
