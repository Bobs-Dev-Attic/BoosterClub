'use strict';

// Cloud Functions backing QR-code sign-in.
//
// The web app creates a `qr_sessions/{id}` document (status: "pending") and
// shows a QR encoding a /pair?s=<id> link. A phone that is already signed in
// opens that link and calls `approveQrSignIn({ sessionId })`. This function
// mints a Firebase custom token for the phone's user and writes it onto the
// session document; the web app then exchanges it via signInWithCustomToken.

const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineString, defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

admin.initializeApp();

// ---- PayPal configuration ------------------------------------------------
// Client id is public; the secret and webhook id are secrets. Set them with:
//   firebase functions:secrets:set PAYPAL_SECRET
//   firebase functions:secrets:set PAYPAL_WEBHOOK_ID
// and PAYPAL_CLIENT_ID / PAYPAL_ENV / APP_URL as build params (or in .env).
const PAYPAL_CLIENT_ID = defineString('PAYPAL_CLIENT_ID', { default: '' });
const PAYPAL_ENV = defineString('PAYPAL_ENV', { default: 'sandbox' }); // or 'live'
const APP_URL = defineString('APP_URL', {
  default: 'https://boosterclub-bda.web.app',
});
const PAYPAL_SECRET = defineSecret('PAYPAL_SECRET');
const PAYPAL_WEBHOOK_ID = defineSecret('PAYPAL_WEBHOOK_ID');

function paypalBase() {
  return PAYPAL_ENV.value() === 'live'
    ? 'https://api-m.paypal.com'
    : 'https://api-m.sandbox.paypal.com';
}

// Exchange client-id/secret for a short-lived OAuth access token.
async function paypalAccessToken() {
  const auth = Buffer.from(
    `${PAYPAL_CLIENT_ID.value()}:${PAYPAL_SECRET.value()}`
  ).toString('base64');
  const res = await fetch(`${paypalBase()}/v1/oauth2/token`, {
    method: 'POST',
    headers: {
      Authorization: `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: 'grant_type=client_credentials',
  });
  if (!res.ok) {
    throw new Error(`PayPal auth failed: ${res.status}`);
  }
  const json = await res.json();
  return json.access_token;
}

const db = () => admin.firestore();

// Creates a PayPal order for a pending donation and returns the approval URL.
exports.createPayPalOrder = onCall(
  { secrets: [PAYPAL_SECRET] },
  async (request) => {
    const donationId = request.data && request.data.donationId;
    if (!donationId || typeof donationId !== 'string') {
      throw new HttpsError('invalid-argument', 'A donationId is required.');
    }
    const ref = db().collection('donations').doc(donationId);
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Donation not found.');
    }
    const d = snap.data();
    if (d.status !== 'pending') {
      throw new HttpsError('failed-precondition', 'Donation is not pending.');
    }
    // If the donation belongs to a signed-in user, only that user may pay it.
    const uid = request.auth && request.auth.uid;
    if (d.uid && d.uid !== uid) {
      throw new HttpsError('permission-denied', 'Not your donation.');
    }
    const amount = Number(d.amount || 0);
    if (!(amount > 0)) {
      throw new HttpsError('invalid-argument', 'Invalid amount.');
    }

    const token = await paypalAccessToken();
    const res = await fetch(`${paypalBase()}/v2/checkout/orders`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        intent: 'CAPTURE',
        purchase_units: [
          {
            custom_id: donationId,
            description: `Donation — ${d.designation || 'Greatest Need'}`,
            amount: {
              currency_code: d.currency || 'USD',
              value: amount.toFixed(2),
            },
          },
        ],
        application_context: {
          brand_name: 'WJ Booster Club',
          user_action: 'PAY_NOW',
          return_url: `${APP_URL.value()}/#/donate?paypal=return`,
          cancel_url: `${APP_URL.value()}/#/donate?paypal=cancel`,
        },
      }),
    });
    if (!res.ok) {
      const body = await res.text();
      throw new HttpsError('internal', `PayPal order failed: ${body}`);
    }
    const order = await res.json();
    const approve = (order.links || []).find((l) => l.rel === 'approve');
    await ref.update({ paypalOrderId: order.id });
    return { orderId: order.id, approveUrl: approve && approve.href };
  }
);

// Captures an approved order and marks the donation completed. Idempotent:
// safe to call alongside the webhook.
exports.capturePayPalOrder = onCall(
  { secrets: [PAYPAL_SECRET] },
  async (request) => {
    const donationId = request.data && request.data.donationId;
    if (!donationId) {
      throw new HttpsError('invalid-argument', 'A donationId is required.');
    }
    const ref = db().collection('donations').doc(donationId);
    const snap = await ref.get();
    if (!snap.exists) throw new HttpsError('not-found', 'Donation not found.');
    const d = snap.data();
    if (d.status === 'completed') return { status: 'completed' };
    if (!d.paypalOrderId) {
      throw new HttpsError('failed-precondition', 'No PayPal order to capture.');
    }

    const token = await paypalAccessToken();
    const res = await fetch(
      `${paypalBase()}/v2/checkout/orders/${d.paypalOrderId}/capture`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );
    const result = await res.json();
    if (result.status === 'COMPLETED') {
      const capture =
        result.purchase_units &&
        result.purchase_units[0].payments &&
        result.purchase_units[0].payments.captures[0];
      await markCompleted(ref, capture && capture.id);
      return { status: 'completed' };
    }
    return { status: (result.status || 'pending').toLowerCase() };
  }
);

async function markCompleted(ref, captureId) {
  await ref.set(
    {
      status: 'completed',
      paypalCaptureId: captureId || null,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

// Finds a donation by its stored PayPal order id.
async function donationByOrderId(orderId) {
  const q = await db()
    .collection('donations')
    .where('paypalOrderId', '==', orderId)
    .limit(1)
    .get();
  return q.empty ? null : q.docs[0].ref;
}

// PayPal webhook — the authoritative source of truth. Verifies the event
// signature with PayPal, then updates the donation ledger. Handles async
// events the client never sees (completed captures, refunds, disputes).
exports.paypalWebhook = onRequest(
  { secrets: [PAYPAL_SECRET, PAYPAL_WEBHOOK_ID] },
  async (req, res) => {
    try {
      const event = req.body;
      const token = await paypalAccessToken();
      const verifyRes = await fetch(
        `${paypalBase()}/v1/notifications/verify-webhook-signature`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            auth_algo: req.header('paypal-auth-algo'),
            cert_url: req.header('paypal-cert-url'),
            transmission_id: req.header('paypal-transmission-id'),
            transmission_sig: req.header('paypal-transmission-sig'),
            transmission_time: req.header('paypal-transmission-time'),
            webhook_id: PAYPAL_WEBHOOK_ID.value(),
            webhook_event: event,
          }),
        }
      );
      const verify = await verifyRes.json();
      if (verify.verification_status !== 'SUCCESS') {
        res.status(400).send('Invalid signature');
        return;
      }

      const type = event.event_type;
      const resource = event.resource || {};

      if (type === 'CHECKOUT.ORDER.APPROVED') {
        // Auto-capture approved orders so the flow completes without the client.
        const ref = await donationByOrderId(resource.id);
        if (ref) {
          const t = await paypalAccessToken();
          const cap = await fetch(
            `${paypalBase()}/v2/checkout/orders/${resource.id}/capture`,
            {
              method: 'POST',
              headers: {
                Authorization: `Bearer ${t}`,
                'Content-Type': 'application/json',
              },
            }
          );
          // The resulting PAYMENT.CAPTURE.COMPLETED event will mark it done.
          await cap.json().catch(() => ({}));
        }
      } else if (type === 'PAYMENT.CAPTURE.COMPLETED') {
        const orderId =
          resource.supplementary_data &&
          resource.supplementary_data.related_ids &&
          resource.supplementary_data.related_ids.order_id;
        const donationId = resource.custom_id;
        let ref = donationId
          ? db().collection('donations').doc(donationId)
          : null;
        if (ref && !(await ref.get()).exists) ref = null;
        if (!ref && orderId) ref = await donationByOrderId(orderId);
        if (ref) await markCompleted(ref, resource.id);
      } else if (
        type === 'PAYMENT.CAPTURE.REFUNDED' ||
        type === 'PAYMENT.CAPTURE.REVERSED'
      ) {
        const donationId = resource.custom_id;
        if (donationId) {
          await db()
            .collection('donations')
            .doc(donationId)
            .set({ status: 'refunded' }, { merge: true });
        }
      }

      res.status(200).send('OK');
    } catch (e) {
      console.error('paypalWebhook error', e);
      res.status(500).send('error');
    }
  }
);

// ---- QR sign-in ----------------------------------------------------------
//
// SECURITY DESIGN (why it's split into two functions):
//
// The custom token that signs a user in is a bearer credential — anyone who
// holds it can sign in as that user. The `qr_sessions` document is PUBLICLY
// READABLE (the waiting web browser is not yet signed in, so it can only poll
// an unauthenticated read). Therefore the token must NEVER be written into that
// document, or any observer of the session id could steal the sign-in.
//
// Instead:
//   1. The web browser generates a high-entropy `secret` locally and stores
//      only its SHA-256 hash on the session doc. The secret is never placed in
//      the QR code or the document — it stays in the browser's memory.
//   2. `approveQrSignIn` (phone, authenticated) only records that the session
//      was approved and by which uid. No token is minted or stored here.
//   3. `claimQrSignIn` (web) proves knowledge of the secret. Only then do we
//      mint the token and RETURN it in the callable response (over HTTPS, never
//      persisted), then delete the single-use session.
//
// Net effect: reading the public session doc reveals nothing usable, and the
// token only ever reaches the browser that created the session.

// Pure helpers live in ./lib/qr so they can be unit-tested without the Admin
// SDK. See functions/qr.test.js.
const { SESSION_TTL_MS, isExpired, secretMatches } = require('./lib/qr');

// Phone side: the already-signed-in user approves a scanned session. Records
// the approval and the approving uid only — no token is created or stored.
exports.approveQrSignIn = onCall(async (request) => {
  const uid = request.auth && request.auth.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'You must be signed in to approve.');
  }

  const sessionId = request.data && request.data.sessionId;
  if (!sessionId || typeof sessionId !== 'string') {
    throw new HttpsError('invalid-argument', 'A sessionId is required.');
  }

  const ref = admin.firestore().collection('qr_sessions').doc(sessionId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'This sign-in request no longer exists.');
  }

  const data = snap.data();
  if (data.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'This request was already used.');
  }
  if (isExpired(data)) {
    await ref.delete();
    throw new HttpsError('deadline-exceeded', 'This sign-in request expired.');
  }

  await ref.update({
    status: 'approved',
    uid,
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});

// Web side: exchange the session (once a phone has approved it) for a custom
// token, proving knowledge of the secret generated when the session was
// created. The token is returned here and NEVER written to Firestore. The
// session is single-use and deleted on success.
exports.claimQrSignIn = onCall(async (request) => {
  const sessionId = request.data && request.data.sessionId;
  const secret = request.data && request.data.secret;
  if (!sessionId || typeof sessionId !== 'string') {
    throw new HttpsError('invalid-argument', 'A sessionId is required.');
  }
  if (!secret || typeof secret !== 'string') {
    throw new HttpsError('invalid-argument', 'A secret is required.');
  }

  const ref = admin.firestore().collection('qr_sessions').doc(sessionId);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'This sign-in request no longer exists.');
  }
  const data = snap.data();

  // Constant-time comparison of the secret hash before doing anything else.
  if (!secretMatches(data.secretHash, secret)) {
    throw new HttpsError('permission-denied', 'Invalid session secret.');
  }

  if (isExpired(data)) {
    await ref.delete();
    throw new HttpsError('deadline-exceeded', 'This sign-in request expired.');
  }
  if (data.status !== 'approved' || !data.uid) {
    throw new HttpsError('failed-precondition', 'Not approved yet.');
  }

  const token = await admin.auth().createCustomToken(data.uid);
  // Single-use: remove the session so the token can never be re-claimed.
  await ref.delete();

  return { token };
});
