'use strict';

const test = require('node:test');
const assert = require('node:assert');
const {
  SESSION_TTL_MS,
  sha256Hex,
  isExpired,
  secretMatches,
} = require('./lib/qr');

test('sha256Hex is deterministic 64-char hex', () => {
  const h = sha256Hex('hello');
  assert.match(h, /^[0-9a-f]{64}$/);
  assert.strictEqual(h, sha256Hex('hello'));
  assert.notStrictEqual(h, sha256Hex('hell0'));
});

test('isExpired respects the 5-minute TTL', () => {
  const now = 1_000_000_000_000;
  assert.strictEqual(isExpired({ createdAt: now - 60_000 }, now), false); // 1 min old
  assert.strictEqual(isExpired({ createdAt: now - SESSION_TTL_MS - 1 }, now), true);
  // Firestore-Timestamp-shaped createdAt is supported too.
  assert.strictEqual(
    isExpired({ createdAt: { toMillis: () => now - 10 } }, now),
    false,
  );
});

test('secretMatches only for the correct secret', () => {
  const secret = 'super-secret-value';
  const hash = sha256Hex(secret);
  assert.strictEqual(secretMatches(hash, secret), true);
  assert.strictEqual(secretMatches(hash, 'wrong'), false);
  assert.strictEqual(secretMatches('', secret), false);
  assert.strictEqual(secretMatches(undefined, secret), false);
});
