// Security-rules tests. Run from firebase/:  npm i -D @firebase/rules-unit-testing firebase
//   npx firebase emulators:exec --only firestore "node test/rules.test.mjs"
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment, assertFails, assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, writeBatch, serverTimestamp, increment, Timestamp, setDoc, getDoc,
  updateDoc, deleteDoc, collection,
} from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'demo-bijli-kab',
  firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
});

const AREA = 'ttsgx8';
const expire = () => Timestamp.fromDate(new Date(Date.now() + 35 * 864e5));

function reportBatch(db, { uid = 'alice', points = 10, on = false, area = AREA, reportUid, extra = {} } = {}) {
  reportUid ??= uid;
  const b = writeBatch(db);
  b.set(doc(collection(db, 'areas', area, 'reports')), {
    uid: reportUid, on, issue: null, at: serverTimestamp(), expire: expire(), ...extra,
  });
  b.set(doc(db, 'areas', area), {
    place: 'Gulberg', city: 'Lahore', lat: 31.5, lng: 74.3, p4: area.slice(0, 4),
    state: on ? 'on' : 'off', since: serverTimestamp(), updated: serverTimestamp(), n: increment(1),
  }, { merge: true });
  b.set(doc(db, 'users', uid), {
    points: increment(points), reports: increment(1), lastReport: serverTimestamp(),
  }, { merge: true });
  return b.commit();
}

const results = [];
async function t(name, fn) {
  try { await fn(); results.push(['ok', name]); }
  catch (e) { results.push(['FAIL', name, e.message]); }
  await env.clearFirestore();
}

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();
const anon = () => env.unauthenticatedContext().firestore();

await t('a normal report succeeds', () => assertSucceeds(reportBatch(alice())));
await t('first-to-report bonus (35 points) succeeds', () => assertSucceeds(reportBatch(alice(), { points: 35 })));
await t('more than 40 points is refused', () => assertFails(reportBatch(alice(), { points: 500 })));
await t('reporting as someone else is refused', () => assertFails(reportBatch(alice(), { reportUid: 'bob' })));
await t('signed-out users cannot report', () => assertFails(reportBatch(anon(), { uid: 'x' })));
await t('a second report within 2 minutes is refused', async () => {
  await assertSucceeds(reportBatch(alice()));
  await assertFails(reportBatch(alice(), { on: true }));
});
await t('another person can report right after', async () => {
  await assertSucceeds(reportBatch(alice()));
  await assertSucceeds(reportBatch(bob(), { uid: 'bob', on: true }));
});
await t('bad area id is refused', () => assertFails(reportBatch(alice(), { area: 'ABC!!!' })));
await t('unknown fields are refused', () => assertFails(reportBatch(alice(), { extra: { spam: 1 } })));
await t('area write without a report is refused', () =>
  assertFails(setDoc(doc(alice(), 'areas', AREA), {
    place: 'x', city: 'y', lat: 1, lng: 2, p4: 'ttsg', state: 'off', updated: serverTimestamp(), n: 1,
  })));
await t('setting own points directly is refused', () =>
  assertFails(setDoc(doc(alice(), 'users', 'alice'), { points: 99999 }, { merge: true })));
await t('profile name/avatar/city can be saved', () =>
  assertSucceeds(setDoc(doc(alice(), 'users', 'alice'), { name: 'Ali', avatar: '🦁', city: 'Lahore' }, { merge: true })));
await t('too-long nickname is refused', () =>
  assertFails(setDoc(doc(alice(), 'users', 'alice'), { name: 'x'.repeat(40) }, { merge: true })));
await t("cannot edit someone else's profile", () =>
  assertFails(setDoc(doc(alice(), 'users', 'bob'), { name: 'hacked' }, { merge: true })));
await t('profile save after a report keeps points', async () => {
  await assertSucceeds(reportBatch(alice()));
  await assertSucceeds(setDoc(doc(alice(), 'users', 'alice'), { name: 'Ali' }, { merge: true }));
});
await t('reports cannot be edited or deleted', async () => {
  const db = alice();
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), 'areas', AREA, 'reports', 'r1'),
      { uid: 'alice', on: false, issue: null, at: Timestamp.now(), expire: expire() });
  });
  await assertFails(updateDoc(doc(db, 'areas', AREA, 'reports', 'r1'), { on: true }));
  await assertFails(deleteDoc(doc(db, 'areas', AREA, 'reports', 'r1')));
});
await t('everyone can read areas, reports and leaderboard', async () => {
  await assertSucceeds(getDoc(doc(anon(), 'areas', AREA)));
  await assertSucceeds(getDoc(doc(anon(), 'areas', AREA, 'reports', 'x')));
  await assertSucceeds(getDoc(doc(anon(), 'users', 'alice')));
});

await env.cleanup();
for (const r of results) console.log(r.join(' — '));
const failed = results.filter((r) => r[0] !== 'ok');
assert.equal(failed.length, 0, `${failed.length} rule test(s) failed`);
console.log(`\nAll ${results.length} rule tests passed.`);
