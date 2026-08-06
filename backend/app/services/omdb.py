import json
import re
from datetime import UTC, datetime, timedelta

import httpx
from fastapi import HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import Episode, Media, Season


class OmdbService:
    base_url = "https://www.omdbapi.com/"

    @staticmethod
    def _now() -> datetime:
        return datetime.now(UTC).replace(tzinfo=None)

    async def _request(self, **params: str) -> dict:
        params["apikey"] = settings.omdb_api_key
        try:
            async with httpx.AsyncClient(timeout=12) as client:
                response = await client.get(self.base_url, params=params)
                response.raise_for_status()
                data = response.json()
        except (httpx.HTTPError, ValueError) as exc:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail={"code": "omdb_unavailable", "message": "OMDb is temporarily unavailable."},
            ) from exc
        if data.get("Response") == "False":
            message = data.get("Error", "OMDb request failed.")
            code = "media_not_found" if "not found" in message.lower() else "omdb_error"
            http_status = status.HTTP_404_NOT_FOUND if code == "media_not_found" else status.HTTP_502_BAD_GATEWAY
            raise HTTPException(status_code=http_status, detail={"code": code, "message": message})
        return data

    @staticmethod
    def _number(value: str | None) -> int:
        match = re.search(r"\d+", value or "")
        return int(match.group()) if match else 0

    @staticmethod
    def _decimal(value: str | None) -> float:
        try:
            return float(value or 0)
        except ValueError:
            return 0

    def _normalize(self, raw: dict, episodes: list[dict] | None = None) -> dict:
        years = re.findall(r"\d{4}", raw.get("Year", ""))
        media_type = "series" if raw.get("Type") == "series" else "movie"
        return {
            "id": raw.get("imdbID"),
            "title": raw.get("Title") or "Untitled",
            "originalTitle": raw.get("Title") or "",
            "type": media_type,
            "posterUrl": "" if raw.get("Poster") in (None, "N/A") else raw["Poster"],
            "backdropUrl": "",
            "overview": "" if raw.get("Plot") == "N/A" else raw.get("Plot", ""),
            "year": int(years[0]) if years else 0,
            "endYear": int(years[-1]) if len(years) > 1 else None,
            "genres": [] if raw.get("Genre") in (None, "N/A") else raw["Genre"].split(", "),
            "rating": self._decimal(raw.get("imdbRating")),
            "runtime": self._number(raw.get("Runtime")),
            "country": raw.get("Country", "-"),
            "director": raw.get("Director", "-"),
            "cast": [] if raw.get("Actors") in (None, "N/A") else raw["Actors"].split(", "),
            "status": "IMDb" if media_type == "series" else "released",
            "episodes": episodes or [],
            "declaredSeasonCount": self._number(raw.get("totalSeasons")),
            "featured": False,
        }

    def _cached(self, db: Session, imdb_id: str, include_episodes: bool) -> dict | None:
        row = db.get(Media, imdb_id)
        if row is None or row.expires_at <= self._now():
            return None
        payload = json.loads(row.payload)
        if include_episodes and payload.get("type") == "series":
            episode_rows = db.scalars(
                select(Episode).where(Episode.media_id == imdb_id).order_by(Episode.season_number, Episode.episode_number)
            ).all()
            if not episode_rows:
                return None
            payload["episodes"] = [self._episode_json(item) for item in episode_rows]
        return payload

    @staticmethod
    def _episode_json(item: Episode) -> dict:
        return {
            "databaseId": item.id,
            "imdbId": item.imdb_id,
            "season": item.season_number,
            "number": item.episode_number,
            "title": item.title,
            "runtime": 0,
            "overview": f"Released: {item.released}" if item.released else "",
            "released": item.released,
            "rating": item.imdb_rating,
        }

    async def details(self, db: Session, imdb_id: str, include_episodes: bool = False) -> dict:
        if not re.fullmatch(r"tt\d+", imdb_id):
            raise HTTPException(422, detail={"code": "invalid_media_id", "message": "A valid IMDb id is required."})
        cached = self._cached(db, imdb_id, include_episodes)
        if cached is not None:
            return cached
        raw = await self._request(i=imdb_id, plot="full")
        normalized = self._normalize(raw)
        expires = self._now() + timedelta(hours=settings.omdb_cache_hours)
        row = db.get(Media, imdb_id)
        if row is None:
            row = Media(
                imdb_id=imdb_id,
                media_type=normalized["type"],
                title=normalized["title"],
                payload=json.dumps(normalized),
                expires_at=expires,
            )
            db.add(row)
        else:
            row.media_type = normalized["type"]
            row.title = normalized["title"]
            row.payload = json.dumps(normalized)
            row.expires_at = expires
        db.flush()
        episode_data: list[dict] = []
        if raw.get("Type") == "series" and include_episodes:
            total = self._number(raw.get("totalSeasons"))
            db.execute(delete(Episode).where(Episode.media_id == imdb_id))
            db.execute(delete(Season).where(Season.media_id == imdb_id))
            db.flush()
            for season_number in range(1, total + 1):
                season_raw = await self._request(i=imdb_id, Season=str(season_number))
                db.add(Season(media_id=imdb_id, number=season_number))
                for item in season_raw.get("Episodes", []):
                    episode = Episode(
                        imdb_id=item.get("imdbID"), media_id=imdb_id, season_number=season_number,
                        episode_number=self._number(item.get("Episode")), title=item.get("Title", "Untitled"),
                        released=None if item.get("Released") == "N/A" else item.get("Released"),
                        imdb_rating=self._decimal(item.get("imdbRating")) or None,
                    )
                    db.add(episode)
                    db.flush()
                    episode_data.append(self._episode_json(episode))
        normalized = self._normalize(raw, episode_data)
        row.payload = json.dumps(normalized)
        db.commit()
        return normalized

    async def search(self, db: Session, query: str, page: int = 1) -> dict:
        raw = await self._request(s=query, page=str(page))
        results = []
        for item in raw.get("Search", []):
            results.append(await self.details(db, item["imdbID"], include_episodes=False))
        return {"items": results, "page": page, "total": self._number(raw.get("totalResults"))}


omdb = OmdbService()
