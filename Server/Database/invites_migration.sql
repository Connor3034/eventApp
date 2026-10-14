-- Invites: allow inviting people who do not have an account yet, and track an
-- invite status (pending / accepted / declined).
-- Idempotent: safe to run more than once.

-- Invitee email (lowercased). user_id may be null until an account exists.
ALTER TABLE Attendance
  ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- status of the invite / attendance
ALTER TABLE Attendance
  ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'accepted';

-- Backfill emails for existing rows that point at a known user.
UPDATE Attendance a
SET email = LOWER(u.email)
FROM Users u
WHERE a.user_id = u.user_id
  AND a.email IS NULL
  AND u.email IS NOT NULL;

-- Existing rows are treated as accepted.
UPDATE Attendance SET status = 'accepted' WHERE status IS NULL;

-- Fast lookups by event/status and user/status.
CREATE INDEX IF NOT EXISTS attendance_event_status_idx ON Attendance (event_id, status);
CREATE INDEX IF NOT EXISTS attendance_user_status_idx ON Attendance (user_id, status);

-- One invite per email per event; lets a declined invite be re-invited.
CREATE UNIQUE INDEX IF NOT EXISTS attendance_event_email_unique
  ON Attendance (event_id, LOWER(email));

-- One row per known user per event (null users are allowed to repeat).
CREATE UNIQUE INDEX IF NOT EXISTS attendance_event_user_unique
  ON Attendance (event_id, user_id);
