from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.encoders import jsonable_encoder
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import select

from .config import settings
from .database import Base, SessionLocal, engine
from .models import User
from .routers import activity, admin, auth, lists, media
from .security import hash_password


@asynccontextmanager
async def lifespan(_: FastAPI):
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        admin_user = db.scalar(select(User).where(User.email == settings.admin_email.lower()))
        if admin_user is None:
            db.add(User(name="System Admin", username="admin", email=settings.admin_email.lower(), password_hash=hash_password(settings.admin_password), role="admin"))
            db.commit()
    yield


app = FastAPI(
    title="FilmYab Advanced API",
    version="1.0.0",
    description="Advanced-model backend for film and series discovery, tracking, reviews, lists, and administration.",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(settings.allowed_origins),
    allow_credentials=settings.allowed_origins != ("*",),
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(HTTPException)
async def http_error(_: Request, exc: HTTPException) -> JSONResponse:
    detail = exc.detail if isinstance(exc.detail, dict) else {"message": str(exc.detail)}
    return JSONResponse(
        status_code=exc.status_code,
        headers=exc.headers,
        content={"error": {"code": detail.get("code", "http_error"), "message": detail.get("message", "Request failed."), "details": detail.get("details")}},
    )


@app.exception_handler(RequestValidationError)
async def validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=422,
        content={"error": {"code": "validation_error", "message": "Request validation failed.", "details": jsonable_encoder(exc.errors())}},
    )


@app.get("/health", tags=["system"])
def health() -> dict:
    return {"status": "ok"}


for router in (auth.router, media.router, activity.router, lists.router, admin.router):
    app.include_router(router, prefix="/api/v1")
