/**
 * Server-side push notification relay.
 *
 * The Firebase service account NEVER leaves Google's servers.
 * The client app calls this HTTPS Callable function with the caller's
 * Firebase Auth token; unauthenticated or malformed requests are rejected.
 *
 * Deploy:
 *   firebase deploy --only functions
 */

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// Simple per-user rate limit: max 60 push requests per minute.
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const RATE_LIMIT_MAX = 60;
const rateBuckets = new Map(); // uid -> { count, windowStart }

function checkRateLimit(uid) {
  const now = Date.now();
  const bucket = rateBuckets.get(uid);
  if (!bucket || now - bucket.windowStart > RATE_LIMIT_WINDOW_MS) {
    rateBuckets.set(uid, { count: 1, windowStart: now });
    return;
  }
  bucket.count += 1;
  if (bucket.count > RATE_LIMIT_MAX) {
    throw new HttpsError("resource-exhausted", "Rate limit exceeded.");
  }
}

exports.sendPushNotification = onCall(
  { region: "us-central1", maxInstances: 10 },
  async (request) => {
    // 1. Authentication is mandatory — no anonymous calls.
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required.");
    }

    // 2. Validate and sanitize input.
    const data = request.data || {};
    const targetToken = String(data.targetToken || "");
    const title = String(data.title || "").slice(0, 100);
    const body = String(data.body || "").slice(0, 200);

    // FCM tokens are long opaque strings; reject anything suspicious.
    if (!/^[A-Za-z0-9_:\-]{100,300}$/.test(targetToken)) {
      throw new HttpsError("invalid-argument", "Invalid target token.");
    }
    if (!title && !body) {
      throw new HttpsError("invalid-argument", "Empty notification.");
    }

    // Only string primitives are allowed in the data payload.
    const extraData = {};
    if (data.data && typeof data.data === "object") {
      for (const [k, v] of Object.entries(data.data)) {
        if (typeof k === "string" && k.length <= 50 && typeof v === "string" && v.length <= 200) {
          extraData[k] = v;
        }
      }
    }

    // 3. Rate limit per caller.
    checkRateLimit(request.auth.uid);

    // 4. Send via Admin SDK (service account stays server-side).
    const message = {
      token: targetToken,
      notification: { title, body },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
        ...extraData,
      },
      android: {
        priority: "high",
        notification: { channel_id: "high_importance_channel", sound: "default" },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    };

    try {
      await getMessaging().send(message);
      return { ok: true };
    } catch (e) {
      // Do not leak internal details to the caller.
      console.error("FCM send failed:", e.code || e.message);
      throw new HttpsError("internal", "Failed to send notification.");
    }
  }
);
