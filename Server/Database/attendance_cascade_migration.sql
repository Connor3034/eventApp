-- Makes Attendance rows cascade when their Event is deleted, so removing an
-- event also removes its attendance records.
-- Idempotent: safe to run more than once.
ALTER TABLE Attendance
  DROP CONSTRAINT IF EXISTS attendance_event_id_fkey;

ALTER TABLE Attendance
  ADD CONSTRAINT attendance_event_id_fkey
  FOREIGN KEY (event_id) REFERENCES Events (event_id) ON DELETE CASCADE;
