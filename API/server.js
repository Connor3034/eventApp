
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

// this is the endpoint for the events table, returning all the rows plus the
// associated user info ordered by the event ids. can_edit is true for the
// creator or anyone with an Attendance row (an invitee); can_delete is true
// only for the creator.
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
          WHERE a.event_id = e.event_id AND a.user_id = $1
        )) AS can_edit,
        (e.user_id = $1) AS can_delete
      FROM Events e
      LEFT JOIN Users u ON e.user_id = u.user_id
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

// this endpoint updates an existing event. the creator or an invitee
// (anyone with an Attendance row for the event) may edit it.
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
          WHERE a.event_id = e.event_id AND a.user_id = $2
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
    const result = await pool.query(
      `INSERT INTO Attendance (event_id, user_id)
       VALUES ($1, $2)
       RETURNING attendance_id, event_id, user_id`,
      [event_id, req.userId]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
// starts the server and on the specified port and keepts it running
app.listen(port, () => {
  console.log(`API server listening on port ${port}`);
});
