'use strict';

// Cloud Functions backing QR-code sign-in.
//
// The web app creates a `qr_sessions/{id}` document (status: "pending") and
// shows a QR encoding a /pair?s=<id> link. A phone that is already signed in
// opens that link and calls `approveQrSignIn({ sessionId })`. This function
// mints a Firebase custom token for the phone's user and writes it onto the
// session document; the web app then exchanges it via signInWithCustomToken.

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const admin = require('firebase-admin');

admin.initializeApp();

const SESSION_TTL_MS = 5 * 60 * 1000; // 5 minutes

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

  const createdAt = data.createdAt && data.createdAt.toMillis
    ? data.createdAt.toMillis()
    : 0;
  if (createdAt && Date.now() - createdAt > SESSION_TTL_MS) {
    await ref.delete();
    throw new HttpsError('deadline-exceeded', 'This sign-in request expired.');
  }

  // Mint a short-lived custom token for the approving user.
  const token = await admin.auth().createCustomToken(uid);

  await ref.update({
    status: 'approved',
    token,
    uid,
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { ok: true };
});
