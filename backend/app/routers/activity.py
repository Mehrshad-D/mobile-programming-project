from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy import delete, func, select

from ..dependencies import CurrentUser, Db
from ..models import Episode, Favorite, Rating, Review, User, WatchStatus, WatchedEpisode
from ..schemas import EpisodeStateIn, RatingIn, ReviewIn, WatchStatusIn


router = APIRouter(tags=["activity"])


@router.put("/me/watch-status/{media_id}")
def set_watch_status(media_id: str, body: WatchStatusIn, user: CurrentUser, db: Db) -> dict:
    row = db.scalar(select(WatchStatus).where(WatchStatus.user_id == user.id, WatchStatus.media_id == media_id))
    if body.status == "none":
        if row:
            db.delete(row)
            db.commit()
        return {"media_id": media_id, "status": "none"}
    if row is None:
        row = WatchStatus(user_id=user.id, media_id=media_id, status=body.status)
        db.add(row)
    else:
        row.status = body.status
    db.commit()
    return {"media_id": media_id, "status": row.status}


@router.put("/me/episodes/{episode_id}/watched")
def set_episode_state(episode_id: int, body: EpisodeStateIn, user: CurrentUser, db: Db) -> dict:
    if db.get(Episode, episode_id) is None:
        raise HTTPException(404, detail={"code": "episode_not_found", "message": "Episode was not found."})
    row = db.scalar(select(WatchedEpisode).where(WatchedEpisode.user_id == user.id, WatchedEpisode.episode_id == episode_id))
    if row is None:
        row = WatchedEpisode(user_id=user.id, episode_id=episode_id, watched=body.watched)
        db.add(row)
    else:
        row.watched = body.watched
    db.commit()
    return {"episode_id": episode_id, "watched": row.watched}


@router.put("/me/ratings/{media_id}")
def rate_media(media_id: str, body: RatingIn, user: CurrentUser, db: Db) -> dict:
    row = db.scalar(select(Rating).where(Rating.user_id == user.id, Rating.media_id == media_id))
    if row is None:
        row = Rating(user_id=user.id, media_id=media_id, value=body.value)
        db.add(row)
    else:
        row.value = body.value
    db.commit()
    return {"media_id": media_id, "value": row.value}


@router.put("/me/favorites/{media_id}", status_code=204)
def add_favorite(media_id: str, user: CurrentUser, db: Db) -> Response:
    exists = db.scalar(select(Favorite).where(Favorite.user_id == user.id, Favorite.media_id == media_id))
    if exists is None:
        db.add(Favorite(user_id=user.id, media_id=media_id))
        db.commit()
    return Response(status_code=204)


@router.delete("/me/favorites/{media_id}", status_code=204)
def remove_favorite(media_id: str, user: CurrentUser, db: Db) -> Response:
    db.execute(delete(Favorite).where(Favorite.user_id == user.id, Favorite.media_id == media_id))
    db.commit()
    return Response(status_code=204)


@router.post("/media/{media_id}/reviews", status_code=status.HTTP_201_CREATED)
def add_review(media_id: str, body: ReviewIn, user: CurrentUser, db: Db) -> dict:
    row = Review(user_id=user.id, media_id=media_id, text=body.text, spoiler=body.spoiler)
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "media_id": media_id, "user": user.username, "text": row.text, "spoiler": row.spoiler, "created_at": row.created_at}


@router.get("/media/{media_id}/reviews")
def list_reviews(media_id: str, db: Db, page: int = 1, page_size: int = 20) -> dict:
    page, page_size = max(page, 1), min(max(page_size, 1), 100)
    rows = db.execute(
        select(Review, User).join(User, User.id == Review.user_id).where(Review.media_id == media_id)
        .order_by(Review.created_at.desc()).offset((page - 1) * page_size).limit(page_size)
    ).all()
    return {"items": [{"id": review.id, "user": user.username, "avatar_url": user.avatar_url, "text": review.text, "spoiler": review.spoiler, "created_at": review.created_at} for review, user in rows], "page": page}


@router.get("/me/activity")
def activity(user: CurrentUser, db: Db) -> dict:
    statuses = db.scalars(select(WatchStatus).where(WatchStatus.user_id == user.id)).all()
    episodes = db.scalars(select(WatchedEpisode).where(WatchedEpisode.user_id == user.id, WatchedEpisode.watched.is_(True))).all()
    ratings = db.scalars(select(Rating).where(Rating.user_id == user.id)).all()
    favorites = db.scalars(select(Favorite).where(Favorite.user_id == user.id)).all()
    return {
        "watch_statuses": [{"media_id": item.media_id, "status": item.status} for item in statuses],
        "watched_episode_ids": [item.episode_id for item in episodes],
        "ratings": [{"media_id": item.media_id, "value": item.value} for item in ratings],
        "favorite_ids": [item.media_id for item in favorites],
        "stats": {"watched_episodes": len(episodes), "rated_titles": len(ratings), "average_rating": db.scalar(select(func.avg(Rating.value)).where(Rating.user_id == user.id)) or 0},
    }
