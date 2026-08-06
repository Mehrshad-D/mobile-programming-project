from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator


class UserRegister(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    username: str = Field(min_length=3, max_length=50, pattern=r"^[\w\u0600-\u06FF.-]+$")
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    bio: str = Field(default="", max_length=1000)


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    username: str
    email: EmailStr
    bio: str
    avatar_url: str | None
    role: str
    is_active: bool
    created_at: datetime


class ProfileUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=120)
    username: str | None = Field(default=None, min_length=3, max_length=50)
    bio: str | None = Field(default=None, max_length=1000)
    avatar_url: str | None = Field(default=None, max_length=500)


class WatchStatusIn(BaseModel):
    status: Literal["plan", "watching", "completed", "paused", "dropped", "favorite", "none"]


class EpisodeStateIn(BaseModel):
    watched: bool


class RatingIn(BaseModel):
    value: int = Field(ge=1, le=5)


class ReviewIn(BaseModel):
    text: str = Field(min_length=1, max_length=3000)
    spoiler: bool = False

    @field_validator("text")
    @classmethod
    def no_blank_review(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("review text cannot be blank")
        return value


class ListCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)


class ListItemIn(BaseModel):
    media_id: str = Field(pattern=r"^tt\d+$")


class ReportIn(BaseModel):
    review_id: int = Field(gt=0)
    reason: str = Field(min_length=3, max_length=500)


class ErrorBody(BaseModel):
    code: str
    message: str
    details: object | None = None


class ErrorResponse(BaseModel):
    error: ErrorBody
