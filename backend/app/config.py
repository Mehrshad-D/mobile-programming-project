import os
from dataclasses import dataclass

from dotenv import load_dotenv


load_dotenv()


@dataclass(frozen=True)
class Settings:
    database_url: str = os.getenv("DATABASE_URL", "sqlite:///./film_management.db")
    jwt_secret: str = os.getenv("JWT_SECRET", "development-only-change-this-secret")
    omdb_api_key: str = os.getenv("OMDB_API_KEY", "")
    omdb_cache_hours: int = int(os.getenv("OMDB_CACHE_HOURS", "24"))
    access_token_minutes: int = int(os.getenv("ACCESS_TOKEN_MINUTES", "43200"))
    admin_email: str = os.getenv("ADMIN_EMAIL", "admin@example.com")
    admin_password: str = os.getenv("ADMIN_PASSWORD", "ChangeMe123!")
    allowed_origins: tuple[str, ...] = tuple(
        value.strip() for value in os.getenv("ALLOWED_ORIGINS", "*").split(",")
    )


settings = Settings()
