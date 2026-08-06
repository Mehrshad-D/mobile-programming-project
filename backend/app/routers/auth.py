from fastapi import APIRouter, HTTPException, status
from sqlalchemy import or_, select

from ..dependencies import CurrentUser, Db
from ..models import User
from ..schemas import LoginRequest, ProfileUpdate, TokenResponse, UserOut, UserRegister
from ..security import create_access_token, hash_password, verify_password


router = APIRouter(tags=["authentication"])


@router.post("/auth/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(body: UserRegister, db: Db) -> TokenResponse:
    exists = db.scalar(select(User).where(or_(User.email == str(body.email).lower(), User.username == body.username)))
    if exists:
        raise HTTPException(409, detail={"code": "account_exists", "message": "Email or username is already registered."})
    user = User(
        name=body.name.strip(), username=body.username.strip(), email=str(body.email).lower(),
        password_hash=hash_password(body.password), bio=body.bio.strip(),
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return TokenResponse(access_token=create_access_token(user.id, user.role))


@router.post("/auth/login", response_model=TokenResponse)
def login(body: LoginRequest, db: Db) -> TokenResponse:
    user = db.scalar(select(User).where(User.email == str(body.email).lower()))
    if user is None or not verify_password(body.password, user.password_hash) or not user.is_active:
        raise HTTPException(401, detail={"code": "invalid_credentials", "message": "Email or password is incorrect."})
    return TokenResponse(access_token=create_access_token(user.id, user.role))


@router.get("/users/me", response_model=UserOut)
def get_profile(user: CurrentUser) -> User:
    return user


@router.patch("/users/me", response_model=UserOut)
def update_profile(body: ProfileUpdate, user: CurrentUser, db: Db) -> User:
    values = body.model_dump(exclude_unset=True)
    if "username" in values:
        exists = db.scalar(select(User).where(User.username == values["username"], User.id != user.id))
        if exists:
            raise HTTPException(409, detail={"code": "username_exists", "message": "Username is already used."})
    for field, value in values.items():
        setattr(user, field, value.strip() if isinstance(value, str) else value)
    db.commit()
    db.refresh(user)
    return user
