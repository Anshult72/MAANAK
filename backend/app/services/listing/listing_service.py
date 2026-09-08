from __future__ import annotations
import ipaddress
import socket
from urllib.parse import urlparse
from typing import Dict, Any, Optional, Tuple
import httpx
from app.core.logging import logger

class OnlineListingService:
    @staticmethod
    def validate_url_security(url_str: str) -> Tuple[bool, str]:
        """
        Enforces strict SSRF protection:
        - Must be http or https
        - Rejects localhost, 127.0.0.1, private IPv4/IPv6 ranges, link-local, file://, etc.
        """
        try:
            parsed = urlparse(url_str)
            if parsed.scheme not in ["http", "https"]:
                return False, "Invalid protocol. Only HTTP and HTTPS are permitted."

            hostname = parsed.hostname
            if not hostname:
                return False, "Invalid hostname in URL."

            if hostname.lower() in ["localhost", "127.0.0.1", "0.0.0.0", "::1"]:
                return False, "Access to localhost or loopback addresses is strictly prohibited."

            # Resolve DNS
            ip_str = socket.gethostbyname(hostname)
            ip_obj = ipaddress.ip_address(ip_str)

            if ip_obj.is_private or ip_obj.is_loopback or ip_obj.is_link_local or ip_obj.is_reserved:
                return False, f"Access to private/internal IP address ({ip_str}) is prohibited."

            return True, "URL is safe for scanning."
        except Exception as e:
            return False, f"URL validation failed: {e}"

    async def fetch_listing_preview(self, safe_url: str) -> Dict[str, Any]:
        """
        Safely fetches e-commerce listing preview with timeouts and size limits.
        """
        is_safe, msg = self.validate_url_security(safe_url)
        if not is_safe:
            raise ValueError(msg)

        try:
            async with httpx.AsyncClient(timeout=10.0, follow_redirects=False) as client:
                request_url = safe_url
                for _ in range(5):
                    response = await client.get(
                        request_url,
                        headers={"User-Agent": "MaanakComplianceBot/1.0"},
                    )
                    if not response.is_redirect:
                        resp = response
                        break
                    redirect_url = str(response.next_request.url) if response.next_request else ""
                    is_safe, message = self.validate_url_security(redirect_url)
                    if not is_safe:
                        raise ValueError(f"Unsafe redirect blocked: {message}")
                    request_url = redirect_url
                else:
                    return {"url": safe_url, "status": "Too many redirects"}

                resp.raise_for_status()
                # Limit content size to 2 MB
                if len(resp.content) > 2 * 1024 * 1024:
                    return {"url": safe_url, "title": "Listing Preview", "status": "Size exceeded limit"}
                return {
                    "url": safe_url,
                    "status": "Fetched",
                    "text_preview": resp.text[:1000]
                }
        except Exception as e:
            logger.warning(f"Error fetching online listing URL: {e}")
            return {"url": safe_url, "status": "Fetch failed", "error": str(e)}

online_listing_service = OnlineListingService()
