from fastapi import APIRouter, Query

from ..dependencies import Db
from ..services.omdb import omdb


router = APIRouter(prefix="/media", tags=["media"])


@router.get("/search")
async def search_media(db: Db, q: str = Query(min_length=2, max_length=100), page: int = Query(1, ge=1, le=100)) -> dict:
    return await omdb.search(db, q.strip(), page)


@router.get("/{imdb_id}")
async def media_details(imdb_id: str, db: Db, include_episodes: bool = False) -> dict:
    return await omdb.details(db, imdb_id, include_episodes)
