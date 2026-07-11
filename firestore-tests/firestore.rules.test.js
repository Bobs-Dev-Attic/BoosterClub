// Firestore security-rules tests, run against the emulator.
//
// These lock down the app's authorization model: role- and grant-based
// permissions, the guards that stop a user from elevating themselves, PII
// privacy on funding requests, gallery visibility, QR-session shape, and the
// donation ledger being server-controlled.
//
// Run with:  npm test   (from firestore-tests/, via the Firestore emulator)

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const path = require('path');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  addDoc,
  collection,
  getDocs,
  query,
  where,
  Timestamp,
} = require('firebase/firestore');
const test = require('node:test');
const assert = require('node:assert');

const RULES = readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-booster',
    firestore: { rules: RULES, host: '127.0.0.1', port: 8080 },
  });
});
test.after(async () => {
  await env.cleanup();
});
test.beforeEach(async () => {
  await env.clearFirestore();
});

// ---- helpers -------------------------------------------------------------

const future = () => Timestamp.fromDate(new Date(Date.now() + 3600 * 1000));
const past = () => Timestamp.fromDate(new Date(Date.now() - 3600 * 1000));

/** Seed a /users/{uid} profile with a base role and optional delegated grants. */
async function seedUser(uid, role, grants) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${uid}`), {
      email: `${uid}@x.org`,
      displayName: uid,
      role,
      grants: grants || {},
    });
  });
}

/** Seed an arbitrary document bypassing rules. */
async function seed(pathStr, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), pathStr), data);
  });
}

/** Firestore handle acting as the given signed-in uid (or guest if null). */
function db(uid) {
  return uid
    ? env.authenticatedContext(uid).firestore()
    : env.unauthenticatedContext().firestore();
}

// ---- users ---------------------------------------------------------------

test('users: signed-in can read; guest cannot', async () => {
  await seedUser('alice', 'member');
  await assertSucceeds(getDoc(doc(db('alice'), 'users/alice')));
  await assertFails(getDoc(doc(db(null), 'users/alice')));
});

test('users: owner can edit profile but not role/grants/committees', async () => {
  await seedUser('alice', 'member');
  const d = db('alice');
  // Editing a normal profile field keeps role/grants/committees unchanged → OK.
  await assertSucceeds(
    setDoc(doc(d, 'users/alice'), {
      email: 'alice@x.org',
      displayName: 'Alice New',
      role: 'member',
      grants: {},
    }, { merge: true }),
  );
  // Self-promotion is denied.
  await assertFails(updateDoc(doc(d, 'users/alice'), { role: 'webAdmin' }));
  // Granting yourself a permission is denied.
  await assertFails(
    updateDoc(doc(d, 'users/alice'), { grants: { manage_gallery: future() } }),
  );
  // Adding yourself to a committee is denied.
  await assertFails(
    updateDoc(doc(d, 'users/alice'), { committees: ['lead_exec'] }),
  );
});

test('users: only manage_users may change another user role/committees', async () => {
  await seedUser('alice', 'member');
  await seedUser('boss', 'webAdmin');
  await assertFails(updateDoc(doc(db('alice'), 'users/boss'), { role: 'member' }));
  await assertSucceeds(
    updateDoc(doc(db('boss'), 'users/alice'), {
      role: 'contributor',
      committees: ['lead_exec'],
    }),
  );
});

// ---- delegated grants ----------------------------------------------------

test('grants: active grant confers permission; expired does not', async () => {
  await seed('gallery/g1', { public: true, title: 'x' });
  // A member with an ACTIVE manage_gallery grant may write gallery.
  await seedUser('helper', 'member', { manage_gallery: future() });
  await assertSucceeds(
    setDoc(doc(db('helper'), 'gallery/g2'), { public: true, title: 'y' }),
  );
  // With an EXPIRED grant, the write is denied.
  await seedUser('lapsed', 'member', { manage_gallery: past() });
  await assertFails(
    setDoc(doc(db('lapsed'), 'gallery/g3'), { public: true, title: 'z' }),
  );
});

// ---- funding requests ----------------------------------------------------

test('funding: guests cannot read; members can; PII subdoc is manager-only', async () => {
  await seed('funding_requests/r1', { title: 'Robotics', status: 'pending' });
  await seed('funding_requests/r1/private/detail', { coachEmail: 'c@x.org' });

  // Guests cannot read the summary at all (was the vulnerability).
  await assertFails(getDoc(doc(db(null), 'funding_requests/r1')));
  // Signed-in members can read the summary.
  await seedUser('mem', 'member');
  await assertSucceeds(getDoc(doc(db('mem'), 'funding_requests/r1')));
  // But NOT the private PII detail.
  await assertFails(getDoc(doc(db('mem'), 'funding_requests/r1/private/detail')));
  // A funding manager can read the private detail.
  await seedUser('fund', 'member', { manage_funding: future() });
  await assertSucceeds(
    getDoc(doc(db('fund'), 'funding_requests/r1/private/detail')),
  );
});

test('funding: members create; non-managers cannot update/delete', async () => {
  await seedUser('mem', 'member');
  const ref = await assertSucceeds(
    addDoc(collection(db('mem'), 'funding_requests'), {
      title: 'Band', status: 'pending',
    }),
  );
  await assertSucceeds(
    setDoc(doc(db('mem'), `funding_requests/${ref.id}/private/detail`), {
      coachEmail: 'c@x.org',
    }),
  );
  await assertFails(updateDoc(doc(db('mem'), `funding_requests/${ref.id}`), { status: 'funded' }));
  await seedUser('fund', 'member', { manage_funding: future() });
  await assertSucceeds(
    updateDoc(doc(db('fund'), `funding_requests/${ref.id}`), { status: 'funded' }),
  );
});

// ---- gallery visibility --------------------------------------------------

test('gallery: hidden docs unreadable by non-managers; managers read all', async () => {
  await seed('gallery/pub', { public: true, title: 'x' });
  await seed('gallery/hid', { public: false, title: 'y' });
  await assertSucceeds(getDoc(doc(db(null), 'gallery/pub')));
  await assertFails(getDoc(doc(db(null), 'gallery/hid')));
  await seedUser('con', 'contributor'); // contributor has manage_gallery
  await assertSucceeds(getDoc(doc(db('con'), 'gallery/hid')));
});

test('gallery: guest list must be filtered to public==true', async () => {
  await seed('gallery/pub', { public: true, title: 'x' });
  await seed('gallery/hid', { public: false, title: 'y' });
  const guest = db(null);
  // Unfiltered list is denied…
  await assertFails(getDocs(collection(guest, 'gallery')));
  // …but a public-only query is allowed.
  await assertSucceeds(
    getDocs(query(collection(guest, 'gallery'), where('public', '==', true))),
  );
});

test('gallery: only managers may write', async () => {
  await seedUser('mem', 'member');
  await assertFails(setDoc(doc(db('mem'), 'gallery/x'), { public: true, title: 't' }));
  await seedUser('con', 'contributor');
  await assertSucceeds(setDoc(doc(db('con'), 'gallery/y'), { public: true, title: 't' }));
});

// ---- qr sessions ---------------------------------------------------------

test('qr_sessions: locked-down create shape; no client update/delete', async () => {
  const guest = db(null);
  // Valid create (unauthenticated web browser).
  await assertSucceeds(
    setDoc(doc(guest, 'qr_sessions/s1'), {
      status: 'pending',
      createdAt: Timestamp.now(),
      secretHash: 'a'.repeat(64),
    }),
  );
  // A token field, or non-pending status, or a short/absent hash → denied.
  await assertFails(
    setDoc(doc(guest, 'qr_sessions/s2'), {
      status: 'pending', createdAt: Timestamp.now(), secretHash: 'a'.repeat(64), token: 't',
    }),
  );
  await assertFails(
    setDoc(doc(guest, 'qr_sessions/s3'), {
      status: 'approved', createdAt: Timestamp.now(), secretHash: 'a'.repeat(64),
    }),
  );
  await assertFails(
    setDoc(doc(guest, 'qr_sessions/s4'), {
      status: 'pending', createdAt: Timestamp.now(), secretHash: 'short',
    }),
  );
  // Get is public (polling); update & delete are denied for clients.
  await seed('qr_sessions/s5', { status: 'approved', createdAt: Timestamp.now(), secretHash: 'a'.repeat(64), uid: 'x' });
  await assertSucceeds(getDoc(doc(guest, 'qr_sessions/s5')));
  await assertFails(updateDoc(doc(guest, 'qr_sessions/s5'), { status: 'pending' }));
  await assertFails(deleteDoc(doc(guest, 'qr_sessions/s5')));
});

// ---- donations -----------------------------------------------------------

test('donations: only a pending self-owned record may be created; no client completion', async () => {
  await seedUser('don', 'member');
  const d = db('don');
  // Valid: pending, own uid, no capture id.
  await assertSucceeds(
    addDoc(collection(d, 'donations'), {
      status: 'pending', uid: 'don', paypalCaptureId: null, amount: 25,
    }),
  );
  // Cannot create an already-completed record…
  await assertFails(
    addDoc(collection(d, 'donations'), {
      status: 'completed', uid: 'don', paypalCaptureId: null, amount: 25,
    }),
  );
  // …nor set a capture id…
  await assertFails(
    addDoc(collection(d, 'donations'), {
      status: 'pending', uid: 'don', paypalCaptureId: 'CAP', amount: 25,
    }),
  );
  // …nor create one owned by someone else.
  await assertFails(
    addDoc(collection(d, 'donations'), {
      status: 'pending', uid: 'someone-else', paypalCaptureId: null, amount: 25,
    }),
  );
});

test('donations: donor reads own; others denied; client cannot update', async () => {
  await seed('donations/dn', { status: 'pending', uid: 'don', amount: 10 });
  await seedUser('don', 'member');
  await seedUser('other', 'member');
  await assertSucceeds(getDoc(doc(db('don'), 'donations/dn')));
  await assertFails(getDoc(doc(db('other'), 'donations/dn')));
  await assertFails(updateDoc(doc(db('don'), 'donations/dn'), { status: 'completed' }));
});

// ---- committees & fundraising orders ------------------------------------

test('committees: public read; only manage_committees writes', async () => {
  await seed('committees/c1', { title: 'Concessions' });
  await assertSucceeds(getDoc(doc(db(null), 'committees/c1')));
  await seedUser('mem', 'member');
  await assertFails(setDoc(doc(db('mem'), 'committees/c2'), { title: 'x' }));
  await seedUser('admin', 'administrator');
  await assertSucceeds(setDoc(doc(db('admin'), 'committees/c3'), { title: 'x' }));
});

test('fundraising_orders: PII gated to fundraising staff', async () => {
  await seed('fundraising_orders/o1', { customerName: 'Jane', campaignId: 'c' });
  await seedUser('mem', 'member');
  await assertFails(getDoc(doc(db('mem'), 'fundraising_orders/o1')));
  await seedUser('vol', 'fundraisingVolunteer');
  await assertSucceeds(getDoc(doc(db('vol'), 'fundraising_orders/o1')));
  // Volunteers may create/update but not delete; managers delete.
  await assertSucceeds(
    updateDoc(doc(db('vol'), 'fundraising_orders/o1'), { fulfillmentStatus: 'packed' }),
  );
  await assertFails(deleteDoc(doc(db('vol'), 'fundraising_orders/o1')));
  await seedUser('fadmin', 'fundraisingAdmin');
  await assertSucceeds(deleteDoc(doc(db('fadmin'), 'fundraising_orders/o1')));
});
