const express = require("express");
const { Pool } = require("pg");
require("dotenv").config();

const app = express();
app.use(express.json());

const port = process.env.PORT || 5000;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

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

app.get("/api/users", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT user_id, user_name FROM Users ORDER BY user_id"
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/users", async (req, res) => {
  const { user_name } = req.body;

  if (!user_name || typeof user_name !== "string" || !user_name.trim()) {
    return res.status(400).json({ error: "user_name is required" });
  }

  try {
    const result = await pool.query(
      "INSERT INTO Users (user_name) VALUES ($1) RETURNING user_id, user_name",
      [user_name.trim()]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/events", async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT
        e.event_id,
        e.event_time,
        e.location,
        e.user_id,
        u.user_name
      FROM Events e
      LEFT JOIN Users u ON e.user_id = u.user_id
      ORDER BY e.event_id
    `);
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post("/api/events", async (req, res) => {
  const { event_time, location, user_id } = req.body;

  if (!event_time || !location) {
    return res.status(400).json({ error: "event_time and location are required" });
  }

  try {
    const result = await pool.query(
      `INSERT INTO Events (event_time, location, user_id)
       VALUES ($1, $2, $3)
       RETURNING event_id, event_time, location, user_id`,
      [event_time, location, user_id ?? null]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get("/api/attendance", async (req, res) => {
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

app.post("/api/attendance", async (req, res) => {
  const { event_id, user_id } = req.body;

  if (!event_id || !user_id) {
    return res.status(400).json({ error: "event_id and user_id are required" });
  }

  try {
    const result = await pool.query(
      `INSERT INTO Attendance (event_id, user_id)
       VALUES ($1, $2)
       RETURNING attendance_id, event_id, user_id`,
      [event_id, user_id]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(port, () => {
  console.log(`API server listening on port ${port}`);
});
