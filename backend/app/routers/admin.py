from fastapi import APIRouter, HTTPException, Response
from sqlalchemy import func, select

from ..dependencies import AdminUser, CurrentUser, Db
from ..models import Media, Report, Review, User
from ..schemas import ReportIn


router = APIRouter(tags=["reports and administration"])


@router.post("/reports", status_code=201)
def report_review(body: ReportIn, user: CurrentUser, db: Db) -> dict:
    if db.get(Review, body.review_id) is None:
        raise HTTPException(404, detail={"code": "review_not_found", "message": "Review was not found."})
    row = Report(reporter_id=user.id, review_id=body.review_id, reason=body.reason.strip())
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "status": row.status}


@router.get("/admin/users")
def users(_: AdminUser, db: Db, page: int = 1, page_size: int = 50) -> dict:
    items = db.scalars(select(User).offset((max(page, 1) - 1) * page_size).limit(min(page_size, 100))).all()
    return {"items": [{"id": user.id, "email": user.email, "username": user.username, "role": user.role, "is_active": user.is_active} for user in items]}


@router.patch("/admin/users/{user_id}/active")
def set_user_active(user_id: int, active: bool, _: AdminUser, db: Db) -> dict:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(404, detail={"code": "user_not_found", "message": "User was not found."})
    user.is_active = active
    db.commit()
    return {"id": user.id, "is_active": user.is_active}


@router.get("/admin/reports")
def reports(_: AdminUser, db: Db) -> list[dict]:
    rows = db.scalars(select(Report).order_by(Report.created_at.desc())).all()
    return [{"id": row.id, "review_id": row.review_id, "reporter_id": row.reporter_id, "reason": row.reason, "status": row.status} for row in rows]


@router.delete("/admin/reviews/{review_id}", status_code=204)
def remove_review(review_id: int, _: AdminUser, db: Db) -> Response:
    review = db.get(Review, review_id)
    if review is None:
        raise HTTPException(404, detail={"code": "review_not_found", "message": "Review was not found."})
    db.delete(review)
    db.commit()
    return Response(status_code=204)


@router.get("/admin/stats")
def stats(_: AdminUser, db: Db) -> dict:
    return {
        "users": db.scalar(select(func.count(User.id))) or 0,
        "cached_media": db.scalar(select(func.count(Media.imdb_id))) or 0,
        "reviews": db.scalar(select(func.count(Review.id))) or 0,
        "open_reports": db.scalar(select(func.count(Report.id)).where(Report.status == "open")) or 0,
    }
