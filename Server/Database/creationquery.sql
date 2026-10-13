-- Fresh database schema for the event planner API.
-- For an existing database that predates auth, apply auth_migration.sql instead
-- (it adds Users.email / Users.password_hash and the unique indexes below).
-- Run with: psql "$DATABASE_URL" -f Server/Database/creationquery.sql

CREATE TABLE IF NOT EXISTS Users (
  user_id SERIAL PRIMARY KEY,
  user_name VARCHAR(255) NOT NULL,
  email VARCHAR(255),
  password_hash VARCHAR(255)
);

CREATE UNIQUE INDEX IF NOT EXISTS users_email_unique
  ON Users (LOWER(email))
  WHERE email IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS users_user_name_unique
  ON Users (LOWER(user_name));

CREATE TABLE IF NOT EXISTS Events (
  event_id SERIAL PRIMARY KEY,
  name VARCHAR(255),
  event_time TIMESTAMPTZ NOT NULL,
  location VARCHAR(255) NOT NULL,
  user_id INTEGER REFERENCES Users (user_id)
);

CREATE TABLE IF NOT EXISTS Attendance (
  attendance_id SERIAL PRIMARY KEY,
  event_id INTEGER REFERENCES Events (event_id),
  user_id INTEGER REFERENCES Users (user_id)
);
