from fastapi import APIRouter, HTTPException, Response, status
from sqlalchemy import delete, select

from ..dependencies import CurrentUser, Db
from ..models import CustomList, ListItem
from ..schemas import ListCreate, ListItemIn


router = APIRouter(prefix="/me/lists", tags=["custom lists"])


def owned_list(list_id: int, user_id: int, db: Db) -> CustomList:
    row = db.scalar(select(CustomList).where(CustomList.id == list_id, CustomList.user_id == user_id))
    if row is None:
        raise HTTPException(404, detail={"code": "list_not_found", "message": "List was not found."})
    return row


@router.get("")
def get_lists(user: CurrentUser, db: Db) -> dict:
    lists = db.scalars(select(CustomList).where(CustomList.user_id == user.id).order_by(CustomList.created_at.desc())).all()
    return {"items": [{"id": item.id, "name": item.name, "media_ids": db.scalars(select(ListItem.media_id).where(ListItem.list_id == item.id)).all()} for item in lists]}


@router.post("", status_code=status.HTTP_201_CREATED)
def create_list(body: ListCreate, user: CurrentUser, db: Db) -> dict:
    row = CustomList(user_id=user.id, name=body.name.strip())
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "name": row.name, "media_ids": []}


@router.delete("/{list_id}", status_code=204)
def delete_list(list_id: int, user: CurrentUser, db: Db) -> Response:
    row = owned_list(list_id, user.id, db)
    db.delete(row)
    db.commit()
    return Response(status_code=204)


@router.put("/{list_id}/items", status_code=201)
def add_item(list_id: int, body: ListItemIn, user: CurrentUser, db: Db) -> dict:
    owned_list(list_id, user.id, db)
    row = db.scalar(select(ListItem).where(ListItem.list_id == list_id, ListItem.media_id == body.media_id))
    if row is None:
        db.add(ListItem(list_id=list_id, media_id=body.media_id))
        db.commit()
    return {"list_id": list_id, "media_id": body.media_id}


@router.delete("/{list_id}/items/{media_id}", status_code=204)
def remove_item(list_id: int, media_id: str, user: CurrentUser, db: Db) -> Response:
    owned_list(list_id, user.id, db)
    db.execute(delete(ListItem).where(ListItem.list_id == list_id, ListItem.media_id == media_id))
    db.commit()
    return Response(status_code=204)
