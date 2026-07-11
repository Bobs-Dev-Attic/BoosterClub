'use strict';

// Pure, dependency-light helpers for QR sign-in — extracted so they can be
// unit-tested without the Firebase Admin SDK or the emulator.

const crypto = require('crypto');

const SESSION_TTL_MS = 5 * 60 * 1000; // 5 minutes

function sha256Hex(value) {
  return crypto.createHash('sha256').update(String(value)).digest('hex');
}

// `data.createdAt` may be a Firestore Timestamp (has toMillis) or a millis
// number (tests). Returns 0 when unknown.
function sessionAgeMs(data, now = Date.now()) {
  const c = data && data.createdAt;
  const createdAt = c && c.toMillis ? c.toMillis() : typeof c === 'number' ? c : 0;
  return createdAt ? now - createdAt : 0;
}

function isExpired(data, now = Date.now()) {
  return sessionAgeMs(data, now) > SESSION_TTL_MS;
}

// Constant-time comparison of a stored secret hash against a provided secret.
function secretMatches(storedHash, providedSecret) {
  const expected = storedHash || '';
  const provided = sha256Hex(providedSecret);
  if (expected.length !== provided.length) return false;
  return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(provided));
}

module.exports = { SESSION_TTL_MS, sha256Hex, sessionAgeMs, isExpired, secretMatches };
