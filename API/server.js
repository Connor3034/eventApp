
// Creates a variable to require express as the backend
const express = require("express");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
// Creates the connection using pool and saying it needs to use the pg library 
const { Pool } = require("pg");
const path = require("path");
// require the .env config file from the Server folder
require("dotenv").config({
  path: path.resolve(__dirname, "..", "Server", ".env"),
});
// creating a variable initalizing express
const app = express();

// telling the app to translate the incoming json into usable data
app.use(express.json());

// creates a port variable using my database on number 5000
const port = process.env.PORT || 5000;
const jwtSecret = process.env.JWT_SECRET || "development-only-change-this-secret";

// uses the connection pool from postgreSQl pg 
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

// creates the root route for the api endpoints 
app.get("/", (req, res) => {
  res.json({
    message: "Event app API is running",
    endpoints: [
      "/api/health",
      "/api/users",
      "/api/events",
      "/api/attendance",
    ],
  });
});

// creates the health api endpoint which returns the current time of day if connection is successful, returns an error message if connection is unsuccessful 
app.get("/api/health", async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW() AS current_time");
    res.json({
      status: "ok",
      database: "connected",
      currentTime: result.rows[0].current_time,
    });
  } catch (error) {
    res.json({
      status: "ok",
      database: "disconnected",
      message: error.message,
    });
  }
});

function createToken(user) {
  return jwt.sign({ userId: user.user_id }, jwtSecret, { expiresIn: "7d" });
}

function publicUser(user) {
  return {
    user_id: user.user_id,
    user_name: user.user_name,
    email: user.email,
  };
}

function requireAuth(req, res, next) {
  const authorization = req.headers.authorization;
  const token = authorization && authorization.startsWith("Bearer ")
    ? authorization.slice(7)
    : null;

  if (!token) {
    return res.status(401).json({ error: "Authentication required" });
  }

  try {
    const payload = jwt.verify(token, jwtSecret);
    req.userId = payload.userId;
    next();
  } catch (error) {
    return res.status(401).json({ error: "Invalid or expired token" });
  }
}

app.post("/api/auth/signup", async (req, res) => {
  const { user_name, email, password } = req.body;
  const normalizedName = typeof user_name === "string" ? user_name.trim() : "";
  const normalizedEmail = typeof email === "string" ? email.trim().toLowerCase() : "";

  if (!normalizedName || !normalizedEmail || typeof password !== "string") {
    return res.status(400).json({ error: "user_name, email, and password are required" });
  }
  if (!/^\S+@\S+\.\S+$/.test(normalizedEmail)) {
    return res.status(400).json({ error: "A valid email is required" });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: "Password must be at least 8 characters" });
  }

  try {
    const passwordHash = await bcrypt.hash(password, 12);
    const result = await pool.query(
      `INSERT INTO Users (user_name, email, password_hash)
       VALUES ($1, $2, $3)
       RETURNING user_id, user_name, email`,
      [normalizedName, normalizedEmail, passwordHash]
    );
    const user = result.rows[0];
    // Claim any invites that were sent to this email before the account existed.
    await pool.query(
      `UPDATE Attendance
       SET user_id = $1
       WHERE user_id IS NULL AND LOWER(email) = $2`,
      [user.user_id, normalizedEmail]
    );
    res.status(201).json({ user: publicUser(user), token: createToken(user) });
  } catch (error) {
    if (error.code === "23505") {
      return res.status(409).json({ error: "Username or email is already in use" });
    }
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/auth/login", async (req, res) => {
  const { email, password } = req.body;
  const normalizedEmail = typeof email === "string" ? email.trim().toLowerCase() : "";

  if (!normalizedEmail || typeof password !== "string" || !password) {
    return res.status(400).json({ error: "email and password are required" });
  }

  try {
    const result = await pool.query(
      "SELECT user_id, user_name, email, password_hash FROM Users WHERE email = $1",
      [normalizedEmail]
    );
    const user = result.rows[0];
    const validPassword = user && await bcrypt.compare(password, user.password_hash);

    if (!validPassword) {
      return res.status(401).json({ error: "Invalid email or password" });
    }

    res.json({ user: publicUser(user), token: createToken(user) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/auth/me", requireAuth, async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT user_id, user_name, email FROM Users WHERE user_id = $1",
      [req.userId]
    );
    if (!result.rows[0]) {
      return res.status(401).json({ error: "User account no longer exists" });
    }
    res.json({ user: publicUser(result.rows[0]) });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// an api endpoint that selects the user id user name ordered by the userid
app.get("/api/users", requireAuth, async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT user_id, user_name FROM Users ORDER BY user_id"
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// this is the endpoint for the events table. It returns only events the caller
// created or has accepted an invite to. can_edit is true for the creator or an
// accepted attendee; can_delete is true only for the creator.
app.get("/api/events", requireAuth, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT
        e.event_id,
        e.name,
        e.event_time,
        e.location,
        e.user_id,
        u.user_name,
        (e.user_id = $1 OR EXISTS (
          SELECT 1 FROM Attendance a
          WHERE a.event_id = e.event_id
            AND a.user_id = $1
            AND a.status = 'accepted'
        )) AS can_edit,
        (e.user_id = $1) AS can_delete
      FROM Events e
      LEFT JOIN Users u ON e.user_id = u.user_id
      WHERE e.user_id = $1 OR EXISTS (
        SELECT 1 FROM Attendance a
        WHERE a.event_id = e.event_id
          AND a.user_id = $1
          AND a.status = 'accepted'
      )
      ORDER BY e.event_id`,
      [req.userId]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// this endpoint sends the event information to the database and creates a new row 
app.post("/api/events", requireAuth, async (req, res) => {
  const { name, event_time, location } = req.body;
  const normalizedName = typeof name === "string" ? name.trim() : "";
  const normalizedLocation = typeof location === "string" ? location.trim() : "";

  if (!normalizedName || !event_time || !normalizedLocation) {
    return res.status(400).json({ error: "name, event_time, and location are required" });
  }

  try {
    const result = await pool.query(
      `INSERT INTO Events (name, event_time, location, user_id)
       VALUES ($1, $2, $3, $4)
       RETURNING event_id, name, event_time, location, user_id`,
      [normalizedName, event_time, normalizedLocation, req.userId]
    );
    res.status(201).json({ ...result.rows[0], can_edit: true, can_delete: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// this endpoint updates an existing event. the creator or an accepted
// attendee may edit it.
app.put("/api/events/:id", requireAuth, async (req, res) => {
  const eventId = Number(req.params.id);
  if (!Number.isInteger(eventId) || eventId <= 0) {
    return res.status(400).json({ error: "A valid event id is required" });
  }

  const { name, event_time, location } = req.body;
  const normalizedName = typeof name === "string" ? name.trim() : "";
  const normalizedLocation = typeof location === "string" ? location.trim() : "";

  if (!normalizedName || !event_time || !normalizedLocation) {
    return res.status(400).json({ error: "name, event_time, and location are required" });
  }

  try {
    const existing = await pool.query(
      `SELECT
        e.user_id,
        (e.user_id = $2 OR EXISTS (
          SELECT 1 FROM Attendance a
          WHERE a.event_id = e.event_id
            AND a.user_id = $2
            AND a.status = 'accepted'
        )) AS can_edit
      FROM Events e
      WHERE e.event_id = $1`,
      [eventId, req.userId]
    );
    const event = existing.rows[0];
    if (!event) {
      return res.status(404).json({ error: "Event not found" });
    }
    if (!event.can_edit) {
      return res.status(403).json({ error: "You cannot edit this event" });
    }

    const result = await pool.query(
      `UPDATE Events
       SET name = $1, event_time = $2, location = $3
       WHERE event_id = $4
       RETURNING event_id, name, event_time, location, user_id`,
      [normalizedName, event_time, normalizedLocation, eventId]
    );
    res.json({
      ...result.rows[0],
      can_edit: true,
      can_delete: event.user_id === req.userId,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// this endpoint deletes an event. only the creator may delete it. any
// attendance rows are removed first so the foreign key does not block it.
app.delete("/api/events/:id", requireAuth, async (req, res) => {
  const eventId = Number(req.params.id);
  if (!Number.isInteger(eventId) || eventId <= 0) {
    return res.status(400).json({ error: "A valid event id is required" });
  }

  try {
    const existing = await pool.query(
      "SELECT user_id FROM Events WHERE event_id = $1",
      [eventId]
    );
    const event = existing.rows[0];
    if (!event) {
      return res.status(404).json({ error: "Event not found" });
    }
    if (event.user_id !== req.userId) {
      return res.status(403).json({ error: "Only the creator can delete this event" });
    }

    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      await client.query("DELETE FROM Attendance WHERE event_id = $1", [eventId]);
      await client.query("DELETE FROM Events WHERE event_id = $1", [eventId]);
      await client.query("COMMIT");
    } catch (error) {
      await client.query("ROLLBACK");
      throw error;
    } finally {
      client.release();
    }

    res.status(204).end();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// this endpoint pulls the attendence information 
app.get("/api/attendance", requireAuth, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        a.attendance_id,
        a.event_id,
        a.user_id,
        e.location,
        u.user_name
      FROM Attendance a
      LEFT JOIN Events e ON a.event_id = e.event_id
      LEFT JOIN Users u ON a.user_id = u.user_id
      ORDER BY a.attendance_id
    `);
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// this endpoint inserts into the attendence table 
app.post("/api/attendance", requireAuth, async (req, res) => {
  const { event_id } = req.body;

  if (!event_id) {
    return res.status(400).json({ error: "event_id is required" });
  }

  try {
    const myEmail = await emailForUser(req.userId);
    const updated = await pool.query(
      `UPDATE Attendance
       SET status = 'accepted', email = COALESCE(email, $3)
       WHERE event_id = $1 AND user_id = $2
       RETURNING attendance_id, event_id, user_id, status`,
      [event_id, req.userId, myEmail]
    );

    if (updated.rows[0]) {
      return res.status(201).json(updated.rows[0]);
    }

    const result = await pool.query(
      `INSERT INTO Attendance (event_id, user_id, email, status)
       VALUES ($1, $2, $3, 'accepted')
       RETURNING attendance_id, event_id, user_id, status`,
      [event_id, req.userId, myEmail]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
// ---------------------------------------------------------------------------
// Invites / attendance
// ---------------------------------------------------------------------------

async function loadEventPermission(eventId, userId) {
  const result = await pool.query(
    `SELECT
      e.user_id,
      (e.user_id = $2 OR EXISTS (
        SELECT 1 FROM Attendance a
        WHERE a.event_id = e.event_id
          AND a.user_id = $2
          AND a.status = 'accepted'
      )) AS allowed
    FROM Events e
    WHERE e.event_id = $1`,
    [eventId, userId]
  );
  return result.rows[0] || null;
}

async function emailForUser(userId) {
  const result = await pool.query(
    "SELECT LOWER(email) AS email FROM Users WHERE user_id = $1",
    [userId]
  );
  return result.rows[0]?.email || null;
}

// Invite someone to an event by email. The creator or an accepted attendee may
// invite. The invitee does not need an account; their user_id is linked when an
// account with that email exists (or is created later).
app.post("/api/events/:id/invite", requireAuth, async (req, res) => {
  const eventId = Number(req.params.id);
  if (!Number.isInteger(eventId) || eventId <= 0) {
    return res.status(400).json({ error: "A valid event id is required" });
  }

  const { email } = req.body || {};
  const normalizedEmail = typeof email === "string" ? email.trim().toLowerCase() : "";

  if (!normalizedEmail || !/^\S+@\S+\.\S+$/.test(normalizedEmail)) {
    return res.status(400).json({ error: "A valid email is required" });
  }

  try {
    const permission = await loadEventPermission(eventId, req.userId);
    if (!permission) {
      return res.status(404).json({ error: "Event not found" });
    }
    if (!permission.allowed) {
      return res.status(403).json({ error: "You cannot invite to this event" });
    }

    const inviterEmail = await emailForUser(req.userId);
    if (normalizedEmail === inviterEmail) {
      return res.status(400).json({ error: "You cannot invite yourself" });
    }

    const found = await pool.query(
      "SELECT user_id, user_name, email FROM Users WHERE LOWER(email) = $1",
      [normalizedEmail]
    );
    const invitee = found.rows[0];
    const inviteeUserId = invitee ? invitee.user_id : null;

    // Re-inviting updates the existing row (e.g. a declined invite) back to
    // pending. An already-accepted attendee stays accepted.
    const updated = await pool.query(
      `UPDATE Attendance
       SET status = CASE WHEN status = 'accepted' THEN 'accepted' ELSE 'pending' END,
           user_id = COALESCE($3::int, user_id),
           email = $2
       WHERE event_id = $1
         AND (LOWER(email) = $2 OR ($3::int IS NOT NULL AND user_id = $3::int))
       RETURNING attendance_id, event_id, user_id, status`,
      [eventId, normalizedEmail, inviteeUserId]
    );

    let row = updated.rows[0];
    let created = false;
    if (!row) {
      const inserted = await pool.query(
        `INSERT INTO Attendance (event_id, user_id, email, status)
         VALUES ($1, $2::int, $3, 'pending')
         RETURNING attendance_id, event_id, user_id, status`,
        [eventId, inviteeUserId, normalizedEmail]
      );
      row = inserted.rows[0];
      created = true;
    }

    res.status(created ? 201 : 200).json({
      ...row,
      user_name: invitee ? invitee.user_name : null,
      email: normalizedEmail,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// List the attendees/invites for an event. Visible to the creator or anyone
// who has an invite (any status) for the event.
app.get("/api/events/:id/attendees", requireAuth, async (req, res) => {
  const eventId = Number(req.params.id);
  if (!Number.isInteger(eventId) || eventId <= 0) {
    return res.status(400).json({ error: "A valid event id is required" });
  }

  try {
    const permission = await loadEventPermission(eventId, req.userId);
    if (!permission) {
      return res.status(404).json({ error: "Event not found" });
    }
    if (permission.user_id !== req.userId && !permission.allowed) {
      const own = await pool.query(
        "SELECT 1 FROM Attendance WHERE event_id = $1 AND user_id = $2",
        [eventId, req.userId]
      );
      if (own.rows.length === 0) {
        return res.status(403).json({ error: "You cannot view this event" });
      }
    }

    const result = await pool.query(
      `SELECT
        a.attendance_id,
        a.event_id,
        a.user_id,
        a.status,
        a.email,
        u.user_name
      FROM Attendance a
      LEFT JOIN Users u ON a.user_id = u.user_id
      WHERE a.event_id = $1
      ORDER BY a.attendance_id`,
      [eventId]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Cancel an invite or remove an attendee. Only the event creator may do this.
// Keyed by attendance id so it works for invitees without an account.
app.delete("/api/events/:id/attendees/:attendanceId", requireAuth, async (req, res) => {
  const eventId = Number(req.params.id);
  const attendanceId = Number(req.params.attendanceId);
  if (!Number.isInteger(eventId) || eventId <= 0 ||
      !Number.isInteger(attendanceId) || attendanceId <= 0) {
    return res.status(400).json({ error: "Valid event and attendee ids are required" });
  }

  try {
    const existing = await pool.query(
      "SELECT user_id FROM Events WHERE event_id = $1",
      [eventId]
    );
    const event = existing.rows[0];
    if (!event) {
      return res.status(404).json({ error: "Event not found" });
    }
    if (event.user_id !== req.userId) {
      return res.status(403).json({ error: "Only the creator can manage attendees" });
    }

    const deleted = await pool.query(
      "DELETE FROM Attendance WHERE attendance_id = $1 AND event_id = $2",
      [attendanceId, eventId]
    );
    if (deleted.rowCount === 0) {
      return res.status(404).json({ error: "Invite not found" });
    }
    res.status(204).end();
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Accept or decline an invite. Only the invited person may change their status.
app.patch("/api/invites/:attendanceId", requireAuth, async (req, res) => {
  const attendanceId = Number(req.params.attendanceId);
  if (!Number.isInteger(attendanceId) || attendanceId <= 0) {
    return res.status(400).json({ error: "A valid invite id is required" });
  }

  const { status } = req.body || {};
  if (status !== "accepted" && status !== "declined") {
    return res.status(400).json({ error: "status must be accepted or declined" });
  }

  try {
    const existing = await pool.query(
      "SELECT user_id, LOWER(email) AS email FROM Attendance WHERE attendance_id = $1",
      [attendanceId]
    );
    const invite = existing.rows[0];
    if (!invite) {
      return res.status(404).json({ error: "Invite not found" });
    }

    const myEmail = await emailForUser(req.userId);
    const isMine = invite.user_id === req.userId ||
      (invite.email != null && invite.email === myEmail);
    if (!isMine) {
      return res.status(403).json({ error: "This invite is not yours" });
    }

    const result = await pool.query(
      `UPDATE Attendance
       SET status = $2, user_id = $3
       WHERE attendance_id = $1
       RETURNING attendance_id, event_id, user_id, status`,
      [attendanceId, status, req.userId]
    );
    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Current user's pending invites, with event details.
app.get("/api/invites", requireAuth, async (req, res) => {
  try {
    const myEmail = await emailForUser(req.userId);
    const result = await pool.query(
      `SELECT
        a.attendance_id,
        a.event_id,
        a.status,
        e.name,
        e.event_time,
        e.location,
        e.user_id,
        u.user_name AS host_name
      FROM Attendance a
      JOIN Events e ON a.event_id = e.event_id
      LEFT JOIN Users u ON e.user_id = u.user_id
      WHERE a.status = 'pending'
        AND (
          a.user_id = $1
          OR ($2::text IS NOT NULL AND LOWER(a.email) = $2)
        )
      ORDER BY e.event_time`,
      [req.userId, myEmail]
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// starts the server and on the specified port and keepts it running
app.listen(port, () => {
  console.log(`API server listening on port ${port}`);
});
