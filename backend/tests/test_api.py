import os
from unittest.mock import AsyncMock

os.environ["DATABASE_URL"] = "sqlite:///./test_film_management.db"
os.environ["JWT_SECRET"] = "test-secret-that-is-long-enough-for-tests"

from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services.omdb import omdb


def auth(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "name": "Test User",
            "username": "tester",
            "email": "test@example.com",
            "password": "StrongPass123!",
        },
    )
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def setup_function() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)


def test_auth_profile_lists_and_validation() -> None:
    with TestClient(app) as client:
        headers = auth(client)
        profile = client.get("/api/v1/users/me", headers=headers)
        assert profile.status_code == 200
        assert profile.json()["email"] == "test@example.com"

        updated = client.patch(
            "/api/v1/users/me",
            headers=headers,
            json={"name": "Updated User", "username": "updated_tester", "bio": "Server profile"},
        )
        assert updated.status_code == 200
        assert updated.json()["name"] == "Updated User"
        assert updated.json()["bio"] == "Server profile"

        duplicate = client.post(
            "/api/v1/auth/register",
            json={"name": "Other", "username": "updated_tester", "email": "other@example.com", "password": "StrongPass123!"},
        )
        assert duplicate.status_code == 409
        assert duplicate.json()["error"]["code"] == "account_exists"

        created = client.post("/api/v1/me/lists", headers=headers, json={"name": "Weekend"})
        assert created.status_code == 201
        list_id = created.json()["id"]
        assert client.put(f"/api/v1/me/lists/{list_id}/items", headers=headers, json={"media_id": "tt0944947"}).status_code == 201
        assert client.get("/api/v1/me/lists", headers=headers).json()["items"][0]["media_ids"] == ["tt0944947"]

        invalid_rating = client.put("/api/v1/me/ratings/tt0944947", headers=headers, json={"value": 6})
        assert invalid_rating.status_code == 422
        assert invalid_rating.json()["error"]["code"] == "validation_error"
        assert client.get("/api/v1/admin/stats", headers=headers).status_code == 403


def test_media_is_normalized_and_all_episodes_are_cached() -> None:
    detail = {
        "Title": "Example Show", "Year": "2020–2021", "Type": "series", "imdbID": "tt1234567",
        "Poster": "N/A", "Plot": "Plot", "Genre": "Drama", "imdbRating": "8.5", "Runtime": "45 min",
        "Country": "US", "Director": "Creator", "Actors": "A, B", "totalSeasons": "2", "Response": "True",
    }
    season_1 = {"Response": "True", "Episodes": [{"Title": "One", "Released": "2020-01-01", "Episode": "1", "imdbRating": "8.0", "imdbID": "tt2000001"}]}
    season_2 = {"Response": "True", "Episodes": [{"Title": "Two", "Released": "2021-01-01", "Episode": "1", "imdbRating": "8.2", "imdbID": "tt2000002"}]}
    omdb._request = AsyncMock(side_effect=[detail, season_1, season_2])
    with TestClient(app) as client:
        response = client.get("/api/v1/media/tt1234567?include_episodes=true")
        assert response.status_code == 200
        data = response.json()
        assert data["declaredSeasonCount"] == 2
        assert [(item["season"], item["number"]) for item in data["episodes"]] == [(1, 1), (2, 1)]

        cached = client.get("/api/v1/media/tt1234567?include_episodes=true")
        assert cached.status_code == 200
        assert omdb._request.await_count == 3
