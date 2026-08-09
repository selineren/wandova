#!/usr/bin/env node
/**
 * backup-legacy-photos.js
 *
 * READ-ONLY backup of legacy `photos` fields from Firestore.
 * Scans every users/{uid}/visits/{visitId} document and, for each one that
 * has a `photos` field, records the document path and the full field
 * contents in tools/legacy-photos-backup.json.
 *
 * This script only ever calls read APIs (collectionGroup().stream()).
 * It never writes, updates, or deletes anything in Firestore.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

// --- Locate the service account key in this directory (never hardcoded) ---
const KEY_PATTERN = /(firebase-adminsdk|service-account).*\.json$/i;
const here = __dirname;
const keyFiles = fs
  .readdirSync(here)
  .filter((f) => KEY_PATTERN.test(f) && f !== 'legacy-photos-backup.json');

if (keyFiles.length === 0) {
  console.error(
    `No service account key found in ${here}\n` +
      'Expected a file matching *firebase-adminsdk*.json or *service-account*.json'
  );
  process.exit(1);
}
if (keyFiles.length > 1) {
  console.error(
    `Multiple candidate key files found in ${here}:\n  ${keyFiles.join('\n  ')}\n` +
      'Remove or rename the ones you do not want used.'
  );
  process.exit(1);
}

const keyPath = path.join(here, keyFiles[0]);
const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'));

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

// Recursively sum the decoded byte size of a photos value.
// - base64 strings count as their decoded binary size
// - other strings count as their UTF-8 byte length
// - Firestore Bytes values (Buffers) count as their raw length
function decodedByteSize(value) {
  if (value == null) return 0;
  if (Buffer.isBuffer(value)) return value.length;
  if (typeof value === 'string') {
    // Treat as base64 if it round-trips cleanly; otherwise count UTF-8 bytes.
    const stripped = value.replace(/\s/g, '');
    if (stripped.length > 0 && /^[A-Za-z0-9+/]+={0,2}$/.test(stripped) && stripped.length % 4 === 0) {
      return Buffer.from(stripped, 'base64').length;
    }
    return Buffer.byteLength(value, 'utf8');
  }
  if (Array.isArray(value)) return value.reduce((sum, v) => sum + decodedByteSize(v), 0);
  if (typeof value === 'object') {
    return Object.values(value).reduce((sum, v) => sum + decodedByteSize(v), 0);
  }
  return 0;
}

async function main() {
  const outPath = path.join(here, 'legacy-photos-backup.json');

  let scanned = 0;
  let withPhotos = 0;
  let totalBytes = 0;
  const affectedUsers = new Set();
  const backup = [];

  const stream = db.collectionGroup('visits').stream();

  for await (const doc of stream) {
    // Only users/{uid}/visits/{visitId} — skip any other 'visits' subcollections.
    const parts = doc.ref.path.split('/');
    if (parts.length !== 4 || parts[0] !== 'users') continue;

    scanned++;
    const data = doc.data();
    if (data && Object.prototype.hasOwnProperty.call(data, 'photos')) {
      withPhotos++;
      affectedUsers.add(parts[1]);
      totalBytes += decodedByteSize(data.photos);
      backup.push({ path: doc.ref.path, photos: data.photos });
    }

    if (scanned % 500 === 0) {
      console.log(`  ...scanned ${scanned} visit documents so far`);
    }
  }

  fs.writeFileSync(outPath, JSON.stringify(backup, null, 2));

  console.log('\nDone. Backup written to', outPath);
  console.log('----------------------------------------');
  console.log(`Visit documents scanned:      ${scanned}`);
  console.log(`Documents with photos field:  ${withPhotos}`);
  console.log(`Distinct users affected:      ${affectedUsers.size}`);
  console.log(`Total decoded byte size:      ${totalBytes} bytes (${(totalBytes / 1024 / 1024).toFixed(2)} MB)`);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error('Backup failed:', err);
    process.exit(1);
  });
