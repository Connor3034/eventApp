# AGENTS.md

Event planner app: Flutter client + Express/Postgres API.

## Layout gotchas

- Real API code is `API/server.js`. `Server/` holds only `.env`, `Database/*.sql`, and `package.json` whose `start` just runs `cd ../API && pnpm start`.
- Real Flutter app is `Client/event_app` (has `lib/`, `test/`).
- Root `package.json` (only `http`) and root `event_app/` (`.idea`/android leftovers, no `lib/`) are stale decoys. Ignore them.
- `node_modules` is gitignored and not committed. Run `pnpm install` in `API` after cloning; the app will not run from a fresh checkout otherwise.
- `Server/.env` is gitignored and local-only (copy `Server/.env.example`). Never commit it; it holds the local Postgres password and JWT secret.

## Backend (API)

- Setup: `cd API && pnpm install && pnpm start` (Express 5, port 5000). Package manager is pnpm; `API/package.json` has no test script.
- `API/server.js` loads env from `../Server/.env` by absolute path, so the `.env` must stay in `Server/` (copy `Server/.env.example`).
- Routes: `GET /api/health` is open; all other `/api/*` routes require `Authorization: Bearer <JWT>`. Tokens come from `POST /api/auth/signup` and `/api/auth/login` (7-day expiry, `JWT_SECRET`).

## Database

- Postgres, tables `Users`, `Events`, `Attendance`.
- Fresh DB: apply `Server/Database/creationquery.sql`. Existing DB: apply `Server/Database/auth_migration.sql` (adds `email`, `password_hash`, unique indexes). Both are idempotent.

## Flutter client

- Commands: `cd Client/event_app && flutter pub get`, `flutter analyze`, `flutter test`, `flutter run`.
- API base URL is compile-time: default `http://10.0.2.2:5000/api` (Android emulator). Override with `--dart-define=API_BASE_URL=http://127.0.0.1:5000/api` for desktop/device.
- Auth state lives in `AuthService` (`ChangeNotifier`); token persisted via `flutter_secure_storage`, user rebuilt from `GET /api/auth/me`.
