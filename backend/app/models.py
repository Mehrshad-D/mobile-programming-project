from datetime import UTC, datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from .database import Base


def now() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(120))
    username: Mapped[str] = mapped_column(String(50), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    bio: Mapped[str] = mapped_column(Text, default="")
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    role: Mapped[str] = mapped_column(String(20), default="user", index=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class Media(Base):
    __tablename__ = "media"
    imdb_id: Mapped[str] = mapped_column(String(20), primary_key=True)
    media_type: Mapped[str] = mapped_column(String(20), index=True)
    title: Mapped[str] = mapped_column(String(300), index=True)
    payload: Mapped[str] = mapped_column(Text)
    cached_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)


class Season(Base):
    __tablename__ = "seasons"
    __table_args__ = (UniqueConstraint("media_id", "number"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    media_id: Mapped[str] = mapped_column(ForeignKey("media.imdb_id", ondelete="CASCADE"), index=True)
    number: Mapped[int] = mapped_column(Integer)


class Episode(Base):
    __tablename__ = "episodes"
    __table_args__ = (UniqueConstraint("media_id", "season_number", "episode_number"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    imdb_id: Mapped[str | None] = mapped_column(String(20), unique=True, nullable=True)
    media_id: Mapped[str] = mapped_column(ForeignKey("media.imdb_id", ondelete="CASCADE"), index=True)
    season_number: Mapped[int] = mapped_column(Integer)
    episode_number: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(300))
    released: Mapped[str | None] = mapped_column(String(30), nullable=True)
    imdb_rating: Mapped[float | None] = mapped_column(Float, nullable=True)


class WatchStatus(Base):
    __tablename__ = "watch_statuses"
    __table_args__ = (UniqueConstraint("user_id", "media_id"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    media_id: Mapped[str] = mapped_column(String(20), index=True)
    status: Mapped[str] = mapped_column(String(30))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)


class WatchedEpisode(Base):
    __tablename__ = "watched_episodes"
    __table_args__ = (UniqueConstraint("user_id", "episode_id"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    episode_id: Mapped[int] = mapped_column(ForeignKey("episodes.id", ondelete="CASCADE"), index=True)
    watched: Mapped[bool] = mapped_column(Boolean, default=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)


class Rating(Base):
    __tablename__ = "ratings"
    __table_args__ = (UniqueConstraint("user_id", "media_id"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    media_id: Mapped[str] = mapped_column(String(20), index=True)
    value: Mapped[int] = mapped_column(Integer)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now, onupdate=now)


class Review(Base):
    __tablename__ = "reviews"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    media_id: Mapped[str] = mapped_column(String(20), index=True)
    text: Mapped[str] = mapped_column(Text)
    spoiler: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class Favorite(Base):
    __tablename__ = "favorites"
    __table_args__ = (UniqueConstraint("user_id", "media_id"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    media_id: Mapped[str] = mapped_column(String(20), index=True)


class CustomList(Base):
    __tablename__ = "custom_lists"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)


class ListItem(Base):
    __tablename__ = "list_items"
    __table_args__ = (UniqueConstraint("list_id", "media_id"),)
    id: Mapped[int] = mapped_column(primary_key=True)
    list_id: Mapped[int] = mapped_column(ForeignKey("custom_lists.id", ondelete="CASCADE"), index=True)
    media_id: Mapped[str] = mapped_column(String(20), index=True)


class Report(Base):
    __tablename__ = "reports"
    id: Mapped[int] = mapped_column(primary_key=True)
    reporter_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    review_id: Mapped[int] = mapped_column(ForeignKey("reviews.id", ondelete="CASCADE"), index=True)
    reason: Mapped[str] = mapped_column(String(500))
    status: Mapped[str] = mapped_column(String(20), default="open", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=now)
