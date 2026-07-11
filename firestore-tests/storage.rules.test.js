// Storage security-rules tests (gallery upload gating, funding read privacy).
// Runs against the Storage + Firestore emulators (gallery uploads do a
// cross-service role() lookup in Firestore).

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const path = require('path');
const { doc, setDoc } = require('firebase/firestore');
const { ref, uploadBytes, getBytes } = require('firebase/storage');
const test = require('node:test');

const F_RULES = readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');
const S_RULES = readFileSync(path.join(__dirname, '..', 'storage.rules'), 'utf8');
const IMG = new Uint8Array([1, 2, 3]);
const META = { contentType: 'image/jpeg' };

let env;
test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-booster',
    firestore: { rules: F_RULES, host: '127.0.0.1', port: 8080 },
    storage: { rules: S_RULES, host: '127.0.0.1', port: 9199 },
  });
});
test.after(async () => env.cleanup());
test.beforeEach(async () => {
  await env.clearFirestore();
  await env.clearStorage();
});

async function seedUser(uid, role) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `users/${uid}`), { role, grants: {} });
  });
}
const stg = (uid) =>
  (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).storage();

test('gallery upload: managers only (member denied, contributor allowed)', async () => {
  await seedUser('mem', 'member');
  await assertFails(uploadBytes(ref(stg('mem'), 'gallery/a.jpg'), IMG, META));
  await seedUser('con', 'contributor');
  await assertSucceeds(uploadBytes(ref(stg('con'), 'gallery/b.jpg'), IMG, META));
});

test('gallery upload: rejects non-image and oversized', async () => {
  await seedUser('con', 'contributor');
  await assertFails(
    uploadBytes(ref(stg('con'), 'gallery/c.txt'), IMG, { contentType: 'text/plain' }),
  );
});

test('funding photo: reads require sign-in', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), 'funding/x.jpg'), IMG, META);
  });
  await assertFails(getBytes(ref(stg(null), 'funding/x.jpg')));
  await seedUser('mem', 'member');
  await assertSucceeds(getBytes(ref(stg('mem'), 'funding/x.jpg')));
});
