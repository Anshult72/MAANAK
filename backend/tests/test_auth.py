import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.security import verify_password, get_password_hash, create_access_token, decode_access_token

def test_argon2_password_hashing():
    pwd = "Inspector@123"
    hashed = get_password_hash(pwd)
    assert hashed != pwd
    assert verify_password(pwd, hashed) is True
    assert verify_password("WrongPassword", hashed) is False

def test_jwt_token_creation_and_decoding():
    data = {"sub": "u-insp-1", "role": "INSPECTOR", "email": "inspector@demo.gov.in"}
    token = create_access_token(data)
    assert isinstance(token, str)
    decoded = decode_access_token(token)
    assert decoded is not None
    assert decoded["sub"] == "u-insp-1"
    assert decoded["role"] == "INSPECTOR"

@pytest.mark.asyncio
async def test_api_login_success():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.post("/api/auth/login", json={
            "email": "inspector@demo.gov.in",
            "password": "Inspector@123"
        })
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["user"]["email"] == "inspector@demo.gov.in"
        assert data["user"]["role"] == "INSPECTOR"

@pytest.mark.asyncio
async def test_api_login_failure():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.post("/api/auth/login", json={
            "email": "inspector@demo.gov.in",
            "password": "IncorrectPassword"
        })
        assert response.status_code == 401
