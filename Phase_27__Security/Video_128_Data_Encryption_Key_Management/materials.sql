-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- Data Encryption & Key Management (Classes 236-237)
-- Phase 27: Security
-- ============================================================

-- ============================================================
-- 1. INSTALL pgcrypto
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Verify:
SELECT * FROM pg_extension WHERE extname = 'pgcrypto';

-- ============================================================
-- 2. CREATE TABLE WITH ENCRYPTED COLUMNS
-- ============================================================

CREATE TABLE patients (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    ssn_encrypted BYTEA,
    diagnosis_encrypted BYTEA,
    ssn_hash TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- 3. INSERT ENCRYPTED DATA
-- ============================================================

-- Use pgp_sym_encrypt with a secret key:
INSERT INTO patients (name, ssn_encrypted, diagnosis_encrypted)
VALUES (
    'Alice Johnson',
    pgp_sym_encrypt('123-45-6789', 'my-secret-key-2026'),
    pgp_sym_encrypt('Type 2 Diabetes', 'my-secret-key-2026')
);

INSERT INTO patients (name, ssn_encrypted, diagnosis_encrypted)
VALUES (
    'Bob Smith',
    pgp_sym_encrypt('987-65-4321', 'my-secret-key-2026'),
    pgp_sym_encrypt('Hypertension', 'my-secret-key-2026')
);

INSERT INTO patients (name, ssn_encrypted, diagnosis_encrypted)
VALUES (
    'Carol Davis',
    pgp_sym_encrypt('555-12-3456', 'my-secret-key-2026'),
    pgp_sym_encrypt('Asthma', 'my-secret-key-2026')
);

-- ============================================================
-- 4. READ ENCRYPTED DATA
-- ============================================================

-- Without decryption (shows binary):
SELECT name, ssn_encrypted FROM patients;

-- With decryption (shows original):
SELECT name,
  pgp_sym_decrypt(ssn_encrypted, 'my-secret-key-2026') AS ssn,
  pgp_sym_decrypt(diagnosis_encrypted, 'my-secret-key-2026') AS diagnosis
FROM patients;

-- Wrong key produces error:
-- SELECT pgp_sym_decrypt(ssn_encrypted, 'wrong-key') FROM patients;
-- ERROR: Wrong key or corrupt data

-- ============================================================
-- 5. SEARCHABLE ENCRYPTION PATTERN
-- ============================================================

-- Store HMAC hash for exact-match lookups:
UPDATE patients SET ssn_hash = encode(
  hmac(
    pgp_sym_decrypt(ssn_encrypted, 'my-secret-key-2026'),
    'hmac-lookup-key',
    'sha256'
  ), 'hex'
);

-- Index the hash column:
CREATE INDEX idx_patients_ssn_hash ON patients (ssn_hash);

-- Search by SSN without decrypting:
SELECT name FROM patients
WHERE ssn_hash = encode(
  hmac('123-45-6789', 'hmac-lookup-key', 'sha256'),
  'hex'
);

-- For new inserts, compute hash at insert time:
INSERT INTO patients (name, ssn_encrypted, diagnosis_encrypted, ssn_hash)
VALUES (
    'Dave Wilson',
    pgp_sym_encrypt('111-22-3333', 'my-secret-key-2026'),
    pgp_sym_encrypt('Migraine', 'my-secret-key-2026'),
    encode(hmac('111-22-3333', 'hmac-lookup-key', 'sha256'), 'hex')
);

-- ============================================================
-- 6. KEY ROTATION
-- ============================================================

BEGIN;

-- Decrypt with OLD key, re-encrypt with NEW key:
UPDATE patients SET
  ssn_encrypted = pgp_sym_encrypt(
    pgp_sym_decrypt(ssn_encrypted, 'my-secret-key-2026'),
    'new-key-2027'
  ),
  diagnosis_encrypted = pgp_sym_encrypt(
    pgp_sym_decrypt(diagnosis_encrypted, 'my-secret-key-2026'),
    'new-key-2027'
  );

COMMIT;

-- Verify with new key:
SELECT name,
  pgp_sym_decrypt(ssn_encrypted, 'new-key-2027') AS ssn
FROM patients;

-- ============================================================
-- 7. BACKUP ENCRYPTION
-- ============================================================

-- pg_dump + GPG encryption:
-- pg_dump -Fc mydb | gpg --symmetric --cipher-algo AES256 \
--   -o /backups/mydb_$(date +%Y%m%d).dump.gpg

-- Decrypt and restore:
-- gpg --decrypt /backups/mydb_20261104.dump.gpg | pg_restore -d mydb

-- pgBackRest with built-in encryption:
-- In /etc/pgbackrest/pgbackrest.conf:
-- [global]
-- repo1-cipher-type=aes-256-cbc
-- repo1-cipher-pass=your-backup-encryption-key

-- ============================================================
-- 8. FULL-DISK ENCRYPTION (LUKS)
-- ============================================================

-- Setup commands (run as root):
-- cryptsetup luksFormat /dev/sdb1
-- cryptsetup luksOpen /dev/sdb1 pgdata_crypt
-- mkfs.ext4 /dev/mapper/pgdata_crypt
-- mount /dev/mapper/pgdata_crypt /var/lib/postgresql/16/main

-- Auto-mount at boot (with key file or manual passphrase):
-- Add to /etc/crypttab:
--   pgdata_crypt /dev/sdb1 none luks

-- Add to /etc/fstab:
--   /dev/mapper/pgdata_crypt /var/lib/postgresql/16/main ext4 defaults 0 2

-- ============================================================
-- 9. SECURITY: PREVENT KEY LEAKAGE
-- ============================================================

-- Prevent keys from appearing in logs:
ALTER ROLE app_user SET log_statement = 'ddl';

-- Use parameterized queries in applications (not literal keys):
-- Python: cursor.execute("SELECT pgp_sym_decrypt(col, %s)", [key])
-- Java:   ps.setString(1, key);

-- Check if pg_stat_statements captures sensitive queries:
-- SELECT query FROM pg_stat_statements WHERE query LIKE '%decrypt%';

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Create a table with encrypted columns. Insert 3 rows.
--    SELECT with and without decryption.

-- 2. Implement searchable encryption:
--    Add HMAC hash column, create index, search by hash.

-- 3. Rotate encryption keys:
--    Decrypt with old key, re-encrypt with new key in one transaction.

-- 4. Encrypt a pg_dump backup with GPG. Then restore it.

-- 5. (Advanced) On a test Linux VM, set up LUKS on a partition
--    and move the PostgreSQL data directory to it.

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS patients;
-- DROP EXTENSION IF EXISTS pgcrypto;
