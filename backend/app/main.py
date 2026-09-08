import os
from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.core.config import settings
from app.core.logging import setup_logging, logger
from app.api.routes import (
    auth, inspections, declarations, findings, reports, products, rules,
    dashboard, audit_logs, online_listings
)

setup_logging()

app = FastAPI(
    title="MAANAK — Legal Metrology Inspection & Compliance Platform",
    description="AI-Assisted Legal Metrology Inspection & Compliance Prototype for SIH 2026 (Problem Statement 26034)",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS configuration
if settings.cors_origins_list == ["*"]:
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=".*",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Mount local server-side storage for prototype image and report viewing
os.makedirs(settings.STORAGE_ROOT, exist_ok=True)
app.mount("/storage", StaticFiles(directory=settings.STORAGE_ROOT), name="storage")

# Include Routers
app.include_router(auth.router)
app.include_router(inspections.router)
app.include_router(declarations.router)
app.include_router(findings.router)
app.include_router(reports.router)
app.include_router(products.router)
app.include_router(rules.router)
app.include_router(dashboard.router)
app.include_router(audit_logs.router)
app.include_router(online_listings.router)

# Consistent API error response handler (Rule 81)
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled error on {request.url.path}: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "success": False,
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An unexpected error occurred while processing the request. Details recorded in audit logs.",
                "details": str(exc) if settings.DEBUG else None
            }
        }
    )

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "MAANAK Legal Metrology Platform",
        "mode": "DEMO_DATA_MODE" if settings.is_demo_mode else "NEON_POSTGRESQL",
        "version": "1.0.0"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
