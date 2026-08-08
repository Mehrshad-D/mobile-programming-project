# FilmYab

FilmYab is a Persian-language film and TV series discovery and tracking application built with Flutter. It was developed as the advanced implementation of a Mobile Programming bachelor project and includes a custom FastAPI backend.

## Features

- Account registration, login, logout, JWT sessions, and profile editing
- Guest access for searching and viewing media details
- Home sections for popular, recent, highly rated, and in-progress titles
- Debounced search by title, actor, director, and genre
- Detailed movie and series information from OMDb
- Complete season and episode retrieval without hard-coded episode data
- Watch statuses, episode tracking, and progress calculation
- Ratings, reviews, and spoiler protection
- Favorites, watchlists, and custom personal lists
- User activity statistics and approximate watch time
- Server-side persistence for authenticated users
- Local caching for catalogue data and guest-mode behavior
- Persian text input and a right-to-left Material interface
- Loading states, image caching, and network error handling

## Architecture

The Flutter application communicates with the project backend through the versioned `/api/v1` interface. It never sends requests directly to OMDb, so the external API key remains on the server.

```text
Flutter application
        |
        | HTTP/JSON + JWT
        v
FastAPI backend
        |-----------------> SQLite / SQLAlchemy
        |
        `-----------------> OMDb API
```

The backend provides authentication, profiles, catalogue normalization, caching, personal activity, lists, reviews, administration, and generated OpenAPI documentation.

## Repository Structure

```text
.
├── android/                 Android runner and debug network configuration
├── backend/                 FastAPI application, database models, and tests
├── lib/
│   ├── data/                Demo catalogue used for presentation/offline UI
│   ├── models/              Application domain models
│   ├── screens/             Flutter screens
│   ├── services/            Backend and catalogue API clients
│   ├── state/               Session, synchronization, and application state
│   └── widgets/             Shared UI components
└── test/                    Flutter unit and widget tests
```

## Prerequisites

- Flutter SDK with Dart 3.11 or later
- Python 3.11 or later
- An OMDb API key

## Backend Setup

From the repository root:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
```

Edit `backend/.env` and configure at least:

```dotenv
OMDB_API_KEY=your-omdb-api-key
JWT_SECRET=replace-with-a-long-random-secret
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=replace-with-a-strong-password
```

Start the backend:

```bash
uvicorn app.main:app --reload
```

The development server is available at:

- API health check: `http://127.0.0.1:8000/health`
- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`

Database tables and the configured administrator account are created automatically during startup.

## Flutter Setup

Keep the backend running, then open another terminal in the repository root:

```bash
flutter pub get
flutter run
```

The default backend address is configured for the Android emulator:

```text
http://10.0.2.2:8000/api/v1
```

Android maps `10.0.2.2` to the development computer's localhost, where FastAPI is running on `127.0.0.1:8000`.

For another target, provide the backend URL at build time:

```bash
flutter run --dart-define=BACKEND_URL=http://127.0.0.1:8000/api/v1
```

Common development addresses:

| Flutter target | Backend URL |
| --- | --- |
| Android emulator | `http://10.0.2.2:8000/api/v1` |
| iOS simulator | `http://127.0.0.1:8000/api/v1` |
| Flutter desktop | `http://127.0.0.1:8000/api/v1` |
| Physical device | `http://<computer-lan-ip>:8000/api/v1` |
| Production | `https://<api-domain>/api/v1` |

For a physical device, start Uvicorn with `--host 0.0.0.0` and make sure the phone and computer are connected to the same network.

## Authentication and Persistence

Passwords are validated and hashed with Argon2 by the backend; plaintext passwords are never stored. Successful registration or login returns a JWT bearer token, which Flutter attaches to authenticated API requests.

Profile changes, watch activity, ratings, reviews, favorites, and personal lists are persisted in the server database. Local preferences are used for the session cache, cached media, and guest-mode state—not as the source of truth for authenticated accounts.

## Tests

Run the backend tests:

```bash
cd backend
source .venv/bin/activate
pytest -q
```

Run Flutter analysis and tests from the repository root:

```bash
flutter analyze
flutter test
```

Backend tests mock OMDb requests, so they do not consume API quota or require internet access.

## API Documentation

The main API groups are:

- Authentication and user profiles
- Movie and series search and details
- Seasons and episodes
- Watch statuses and watched episodes
- Ratings, reviews, and favorites
- Personal lists and activity
- Reports and administrator operations

For complete request and response schemas, run the backend and open `http://127.0.0.1:8000/docs`.

## Production Notes

- Replace all example secrets and administrator credentials.
- Serve the backend through HTTPS.
- Restrict `ALLOWED_ORIGINS` instead of using `*`.
- Use a production database such as PostgreSQL through `DATABASE_URL`.
- Do not commit `.env`, database files, or generated tokens.
- The Android cleartext-traffic exception is limited to debug builds for local development.
