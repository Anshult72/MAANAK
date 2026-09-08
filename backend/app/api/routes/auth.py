from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.domain import LoginRequest, TokenResponse, UserResponse
from app.repositories import get_repository
from app.core.security import verify_password, create_access_token, get_current_user_payload
from app.core.logging import logger

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

@router.post("/login", response_model=TokenResponse)
async def login(req: LoginRequest):
    repo = get_repository()
    user = await repo.get_by_email(req.email)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_CREDENTIALS", "message": "Invalid officer email or password", "details": None}
        )

    if not verify_password(req.password, user["hashed_password"]):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": "INVALID_CREDENTIALS", "message": "Invalid officer email or password", "details": None}
        )

    token = create_access_token({
        "sub": user["id"],
        "email": user["email"],
        "role": user["role"],
        "officer_id": user["officer_id"],
        "full_name": user["full_name"]
    })

    # Log audit event
    await repo.append_log({
        "user_id": user["id"],
        "role": user["role"],
        "action": "USER_LOGIN",
        "resource_type": "AUTH",
        "resource_id": user["id"],
        "metadata": {"officer_id": user["officer_id"]}
    })

    user_out = {k: v for k, v in user.items() if k != "hashed_password"}
    return TokenResponse(access_token=token, user=user_out)

@router.get("/me", response_model=UserResponse)
async def get_me(payload: dict = Depends(get_current_user_payload)):
    repo = get_repository()
    user = await repo.get_by_id(payload["sub"])
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserResponse(
        id=user["id"],
        email=user["email"],
        full_name=user["full_name"],
        officer_id=user["officer_id"],
        department=user["department"],
        role=user["role"],
        active=user["active"]
    )
