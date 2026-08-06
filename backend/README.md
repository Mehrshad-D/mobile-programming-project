# FilmYab Advanced Backend

FastAPI backend for the advanced model of the Mobile Programming project.

## Implemented requirements

- Custom versioned mobile API (`/api/v1`)
- Registration, login, JWT bearer authentication and 30-day configurable tokens
- Argon2 password hashing; plaintext passwords are never stored
- User and administrator roles with protected admin endpoints
- Server-side validation and a consistent `{ "error": { "code", "message", "details" } }` format
- OMDb proxy: the external key stays on the server
- Normalized movie, series, season and episode responses
- Persistent OMDb cache with configurable expiration and offline reuse
- SQLite database, replaceable through `DATABASE_URL` with PostgreSQL or another SQLAlchemy database
- Watch statuses, watched episodes, ratings, reviews, favorites and user activity
- Personal lists and list items
- User reports, comment moderation, account management and system statistics
- Pagination for search, reviews and users
- Interactive Swagger (`/docs`) and ReDoc (`/redoc`) documentation
- CORS configuration, health endpoint, tests and Docker support

## Run locally

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Put your OMDb key in .env and replace the example JWT/admin secrets.
uvicorn app.main:app --reload
```

Open `http://127.0.0.1:8000/docs`. The database and tables are created automatically. Change the default administrator password before first production use.

For the Android emulator, the Flutter app defaults to `http://10.0.2.2:8000/api/v1`. Override it for a device or deployed HTTPS server:

```bash
flutter run --dart-define=BACKEND_URL=https://api.example.com/api/v1
```

Use HTTPS in production and terminate TLS with a trusted certificate at a reverse proxy such as Caddy, Nginx or Cloudflare. The debug Android manifest permits cleartext only for local development.

## Test

```bash
pytest -q
```

Tests mock OMDb, so they do not consume API quota or require internet access.

## Main endpoints

| Method | Endpoint | Access |
| --- | --- | --- |
| POST | `/api/v1/auth/register` | Public |
| POST | `/api/v1/auth/login` | Public |
| GET/PATCH | `/api/v1/users/me` | User |
| GET | `/api/v1/media/search?q=...` | Public |
| GET | `/api/v1/media/{imdb_id}?include_episodes=true` | Public |
| PUT | `/api/v1/me/watch-status/{imdb_id}` | User |
| PUT | `/api/v1/me/episodes/{episode_id}/watched` | User |
| PUT | `/api/v1/me/ratings/{imdb_id}` | User |
| POST/GET | `/api/v1/media/{imdb_id}/reviews` | User/Public |
| PUT/DELETE | `/api/v1/me/favorites/{imdb_id}` | User |
| GET/POST | `/api/v1/me/lists` | User |
| PUT/DELETE | `/api/v1/me/lists/{id}/items` | User |
| GET | `/api/v1/me/activity` | User |
| POST | `/api/v1/reports` | User |
| GET/PATCH | `/api/v1/admin/users...` | Admin |
| GET | `/api/v1/admin/reports` | Admin |
| DELETE | `/api/v1/admin/reviews/{id}` | Admin |
| GET | `/api/v1/admin/stats` | Admin |
