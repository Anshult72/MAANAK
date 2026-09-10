import logging
import sys
import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request


def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )


logger = logging.getLogger("maanak")


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Logs method, path, status, and duration for every request.

    Secrets (DATABASE_URL, API keys, JWT_SECRET, Authorization headers)
    are never included in log output.
    """

    async def dispatch(self, request: Request, call_next):
        start = time.monotonic()
        response = None
        try:
            response = await call_next(request)
            return response
        finally:
            duration_ms = round((time.monotonic() - start) * 1000, 1)
            status_code = response.status_code if response else 500
            logger.info(
                "%s %s → %s (%sms)",
                request.method,
                request.url.path,
                status_code,
                duration_ms,
            )
