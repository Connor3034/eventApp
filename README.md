# eventApp
A  mobile app that allows events to be created easily 

## Authentication setup

The API now supports username, email, and password accounts through:

- `POST /api/auth/signup`
- `POST /api/auth/login`
- `GET /api/auth/me`

Set `DATABASE_URL` and `JWT_SECRET` in `Server/.env` before starting the API. Apply `Server/Database/creationquery.sql` for a new database. For an existing database, apply `Server/Database/auth_migration.sql`; existing users keep their event relationships but must create new credentials.

The Flutter client defaults to `http://10.0.2.2:5000/api` for an Android emulator. Use `--dart-define=API_BASE_URL=http://127.0.0.1:5000/api` for desktop or an API URL reachable from a physical device.
