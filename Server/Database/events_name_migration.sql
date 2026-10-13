-- Adds the Events.name column for databases created before event names existed.
-- Idempotent: safe to run more than once.
ALTER TABLE Events
  ADD COLUMN IF NOT EXISTS name VARCHAR(255);
