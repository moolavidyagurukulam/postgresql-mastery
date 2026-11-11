-- ============================================================
-- PostgreSQL Mastery — Class Materials
-- pgcrypto — Encryption & Hashing (Class 224)
-- Phase 26: Extensions
-- ============================================================

-- ============================================================
-- INSTALLATION
-- ============================================================

-- Trusted extension — no restart needed:
CREATE EXTENSION pgcrypto;

-- Verify:
SELECT extname, extversion FROM pg_extension WHERE extname = 'pgcrypto';
-- \dx pgcrypto
-- \dx+ pgcrypto  (see all functions)

-- ============================================================
-- 1. HASHING WITH digest()
-- ============================================================

-- SHA-256 hash:
SELECT encode(digest('Hello, World!', 'sha256'), 'hex') AS sha256_hash;

-- SHA-512 hash:
SELECT encode(digest('Hello, World!', 'sha512'), 'hex') AS sha512_hash;

-- Same input always produces the same hash:
SELECT encode(digest('password123', 'sha256'), 'hex');
SELECT encode(digest('password123', 'sha256'), 'hex');
-- Identical output!

-- Supported algorithms: md5, sha1, sha224, sha256, sha384, sha512
-- Use SHA-256 or higher — MD5 and SHA-1 are weak

-- ============================================================
-- 2. KEYED HASHING WITH hmac()
-- ============================================================

-- HMAC with a secret key:
SELECT encode(hmac('message', 'secret-key', 'sha256'), 'hex') AS hmac_hash;

-- Different key = completely different hash:
SELECT encode(hmac('message', 'wrong-key', 'sha256'), 'hex') AS wrong_hmac;

-- Use case: API request signing, data authenticity

-- ============================================================
-- 3. PASSWORD HASHING WITH crypt() & gen_salt()
-- ============================================================

-- Hash a password with bcrypt:
SELECT crypt('mypassword', gen_salt('bf'));
-- $2a$06$... (different every time — random salt)

-- Hash again — different result!
SELECT crypt('mypassword', gen_salt('bf'));

-- Verify a password (compare hash with stored hash):
-- crypt('input', stored_hash) = stored_hash → match!

-- Practical: users table with hashed passwords:
CREATE TABLE app_users (
    id serial PRIMARY KEY,
    username text UNIQUE NOT NULL,
    password_hash text NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- Register a user:
INSERT INTO app_users (username, password_hash)
VALUES ('alice', crypt('SecurePass1!', gen_salt('bf', 10)));

-- Login check:
SELECT id, username FROM app_users
WHERE username = 'alice'
  AND password_hash = crypt('SecurePass1!', password_hash);

-- Wrong password returns no rows:
SELECT id, username FROM app_users
WHERE username = 'alice'
  AND password_hash = crypt('WrongPass', password_hash);

-- ============================================================
-- gen_salt() OPTIONS
-- ============================================================

-- gen_salt('bf')       — bcrypt, default cost 6
-- gen_salt('bf', 10)   — bcrypt, cost 10 (recommended for production)
-- gen_salt('bf', 12)   — bcrypt, cost 12 (slower but more secure)
-- gen_salt('md5')      — NOT recommended
-- gen_salt('des')      — NOT recommended
-- gen_salt('xdes')     — NOT recommended

-- ============================================================
-- 4. SYMMETRIC ENCRYPTION — encrypt() / decrypt()
-- ============================================================

-- Encrypt with AES:
SELECT encrypt(
    'Secret data: 4111-1111-1111-1111',
    'my-encryption-key',
    'aes'
) AS encrypted_data;

-- Decrypt:
SELECT convert_from(
    decrypt(
        encrypt('Secret data: 4111-1111-1111-1111', 'my-encryption-key', 'aes'),
        'my-encryption-key',
        'aes'
    ),
    'UTF8'
) AS decrypted;

-- With initialization vector (more secure):
SELECT encrypt_iv(
    'Sensitive data'::bytea,
    'my-encryption-key'::bytea,
    'random-iv-value!'::bytea,  -- 16 bytes for AES
    'aes'
);

-- Supported algorithms: aes, bf (Blowfish), 3des

-- ============================================================
-- 5. PGP SYMMETRIC ENCRYPTION
-- ============================================================

-- PGP symmetric encrypt:
SELECT pgp_sym_encrypt('My secret message', 'strong-passphrase');

-- Decrypt:
SELECT pgp_sym_decrypt(
    pgp_sym_encrypt('My secret message', 'strong-passphrase'),
    'strong-passphrase'
);

-- With options:
SELECT pgp_sym_encrypt(
    'My secret message',
    'passphrase',
    'compress-algo=1, cipher-algo=aes256'
);

-- ============================================================
-- 6. PRACTICAL: ENCRYPTED COLUMNS
-- ============================================================

CREATE TABLE sensitive_data (
    id serial PRIMARY KEY,
    name text NOT NULL,
    encrypted_email bytea NOT NULL,
    encrypted_ssn bytea
);

-- Insert with encryption:
INSERT INTO sensitive_data (name, encrypted_email, encrypted_ssn)
VALUES (
    'Alice Smith',
    pgp_sym_encrypt('alice@example.com', 'app-secret-key'),
    pgp_sym_encrypt('123-45-6789', 'app-secret-key')
);

-- Read encrypted (gibberish):
SELECT name, encrypted_email FROM sensitive_data;

-- Decrypt to read:
SELECT name,
    pgp_sym_decrypt(encrypted_email, 'app-secret-key') AS email,
    pgp_sym_decrypt(encrypted_ssn, 'app-secret-key') AS ssn
FROM sensitive_data;

-- ============================================================
-- 7. RANDOM DATA GENERATION
-- ============================================================

-- Random bytes (hex):
SELECT encode(gen_random_bytes(16), 'hex') AS random_hex;

-- Random bytes (base64 — good for tokens):
SELECT encode(gen_random_bytes(32), 'base64') AS api_token;

-- UUID v4 (also available without pgcrypto in PG 13+):
SELECT gen_random_uuid();

-- ============================================================
-- PRACTICE EXERCISES
-- ============================================================

-- 1. Install pgcrypto and list its functions with \dx+ pgcrypto.

-- 2. Hash the string 'PostgreSQL' with SHA-256 and SHA-512.
--    Compare the output lengths.

-- 3. Create a users table and insert a user with a bcrypt-hashed
--    password (cost factor 10). Then verify the password.

-- 4. Encrypt a message with pgp_sym_encrypt and decrypt it back.

-- 5. Create a table with an encrypted column. Insert data,
--    then query it — first without decrypting, then with.

-- 6. Generate 5 random UUIDs using gen_random_uuid().

-- ============================================================
-- CLEANUP
-- ============================================================
-- DROP TABLE IF EXISTS app_users;
-- DROP TABLE IF EXISTS sensitive_data;
-- DROP EXTENSION IF EXISTS pgcrypto;
