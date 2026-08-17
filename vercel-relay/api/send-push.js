/**
 * Free push-notification relay for Vercel (Hobby plan — no card required).
 *
 * Secrets live ONLY in Vercel Environment Variables, never in the app:
 *   FIREBASE_SERVICE_ACCOUNT  = full service-account JSON (one line)
 *   RELAY_SECRET              = shared secret the app must send in header x-relay-key
 *
 * Endpoint: POST https://<your-project>.vercel.app/api/send-push
 */

const admin = require("firebase-admin");

// ---- Init Admin SDK once per warm instance (Vercel reuses instances) ----
if (!admin.apps.length) {
  const saJson = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!saJson) throw new Error("Missing FIREBASE_SERVICE_ACCOUNT env var");
  admin.initializeApp({
    credential: admin.credential.cert(JSON.parse(saJson)),
  });
}

// ---- Simple in-memory rate limit: 60 req/min per instance ----
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_MAX = 60;
const buckets = new Map();

function checkRateLimit(key) {
  const now = Date.now();
  const b = buckets.get(key);
  if (!b || now - b.start > RATE_LIMIT_WINDOW_MS) {
    buckets.set(key, { count: 1, start: now });
    return true;
  }
  b.count += 1;
  return b.count <= RATE_LIMIT_MAX;
}

// Constant-time-ish string compare
function safeEqual(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

module.exports = async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "method_not_allowed" });
    }

    // 1. Shared-secret check — blocks strangers from abusing the relay.
    const key = req.headers["x-relay-key"];
    if (!process.env.RELAY_SECRET || !safeEqual(key, process.env.RELAY_SECRET)) {
      return res.status(401).json({ error: "unauthorized" });
    }

    // 2. Rate limit.
    if (!checkRateLimit("relay")) {
      return res.status(429).json({ error: "rate_limited" });
    }

    // 3. Validate input.
    const body = typeof req.body === "object" && req.body ? req.body : {};
    const targetToken = String(body.targetToken || "");
    const title = String(body.title || "").slice(0, 100);
    const msgBody = String(body.body || "").slice(0, 200);

    if (!/^[A-Za-z0-9_:\-]{100,300}$/.test(targetToken)) {
      return res.status(400).json({ error: "invalid_token" });
    }
    if (!title && !msgBody) {
      return res.status(400).json({ error: "empty_notification" });
    }

    const data = { click_action: "FLUTTER_NOTIFICATION_CLICK" };
    if (body.data && typeof body.data === "object") {
      for (const [k, v] of Object.entries(body.data)) {
        if (typeof k === "string" && k.length <= 50 && typeof v === "string" && v.length <= 200) {
          data[k] = v;
        }
      }
    }

    // 4. Send via Admin SDK.
    await admin.messaging().send({
      token: targetToken,
      notification: { title, body: msgBody },
      data,
      android: {
        priority: "high",
        notification: { channel_id: "high_importance_channel", sound: "default" },
      },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });

    return res.status(200).json({ ok: true });
  } catch (e) {
    console.error("relay error:", e.code || e.message);
    return res.status(500).json({ error: "internal" });
  }
};
