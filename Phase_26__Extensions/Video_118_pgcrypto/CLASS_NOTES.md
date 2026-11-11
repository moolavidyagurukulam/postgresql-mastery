# pgcrypto — Encryption & Hashing
**Series:** PostgreSQL Mastery | **Phase:** Phase 26: Extensions | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Sensitive data in your database — passwords, credit card numbers, personal information — needs protection. pgcrypto is a trusted extension that brings cryptographic functions directly into PostgreSQL. You can hash passwords with bcrypt, encrypt columns with AES, generate random data, and create secure digests. Let us learn how to protect data at the database level.


---

## 2. Core Technical Concepts & Mechanisms

### Hashing vs Encryption
First, the difference between hashing and encryption. Hashing is one-way — you cannot reverse a hash to get the original data. It is used for passwords and data integrity. Encryption is two-way — you encrypt with a key and decrypt with the same key or a paired key. It is used when you need the original data back.

| Hashing (One-Way) | Encryption (Two-Way) |
| :--- | :--- |
| Cannot reverse to get original | Can decrypt back to original |
| Same input → same hash always | Requires a key to encrypt/decrypt |
| Used for: password storage | Used for: sensitive data storage |
| Used for: data integrity checks | Used for: data at rest protection |
| Functions: digest(), crypt() | Functions: encrypt(), decrypt() |
| Algorithms: SHA-256, SHA-512, bcrypt | Algorithms: AES-256, 3DES, Blowfish |

### gen_salt Options
The gen_salt function controls the algorithm and work factor. A higher work factor means slower hashing — which makes brute-force attacks harder. The default bcrypt work factor is 6, but production should use 10 to 12.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | The gen_salt function controls the algorithm and work factor |
| **Point 2** | A higher work factor means slower hashing — which makes brute-force attacks harder |
| **The default bcrypt work factor is 6** | but production should use 10 to 12 |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### pgcrypto Security Best Practices
Security best practices when using pgcrypto. Never store encryption keys in the database itself. Never log decrypted data. Always use bcrypt for passwords — never SHA-256 alone. And remember that encrypted columns cannot be searched or indexed efficiently.

| Do This | Avoid This |
| :--- | :--- |
| Store encryption keys outside the DB | Storing keys in the same database |
| Use bcrypt (gen_salt('bf', 10+)) for passwords | Using MD5 or SHA-1 for passwords |
| Use AES-256 or PGP for column encryption | Logging decrypted sensitive data |
| Rotate encryption keys periodically | Hardcoding keys in SQL scripts |
| Hash API keys, store only the hash | Searching on encrypted columns (slow) |
| Use encrypt_iv with random IV | Using DES or 3DES (weak/obsolete) |

### pgcrypto Functions Reference
Here is a quick reference of all pgcrypto functions organized by purpose. Keep this table handy — it covers everything from hashing to encryption to random generation.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a quick reference of all pgcrypto functions organized by purpose |
| **Keep this table handy** | it covers everything from hashing to encryption to random generation |


---

## 3. Hands-On Commands & psql Output

### Installing pgcrypto
**Explanation:** Installing pgcrypto is straightforward — it is an official trusted PostgreSQL contrib extension. Execute CREATE EXTENSION IF NOT EXISTS pgcrypto in your target database. No server restart is required. It immediately provides cryptographic hashing, Blowfish password salting, HMAC, and AES symmetric encryption.

```sql
postgres=# -- Install (trusted — non-superuser can install too):
postgres=# CREATE EXTENSION pgcrypto;
postgres=# -- Verify:
\dx pgcrypto
   Name   | Version |  Schema  |      Description
postgres=# ----------+---------+----------+------------------------
 pgcrypto | 1.3     | public   | cryptographic functions
postgres=# -- See all functions:
\dx+ pgcrypto
postgres=# -- digest, hmac, crypt, gen_salt,
postgres=# -- encrypt, decrypt, encrypt_iv, decrypt_iv,
postgres=# -- pgp_sym_encrypt, pgp_sym_decrypt,
postgres=# -- pgp_pub_encrypt, pgp_pub_decrypt,
postgres=# -- gen_random_bytes, gen_random_uuid,
postgres=# -- armor, dearmor
```

### digest() — Hashing Data
**Explanation:** The digest function creates a hash of any data. It supports MD5, SHA-1, SHA-224, SHA-256, SHA-384, and SHA-512. Always use SHA-256 or higher — MD5 and SHA-1 are considered weak.

```sql
postgres=# -- SHA-256 hash:
postgres=# SELECT encode(
    digest('Hello, World!', 'sha256'),
    'hex'
) AS sha256_hash;
postgres=# -- dffd6021bb2bd5b0af676290809ec3a5...
postgres=# -- SHA-512 hash:
postgres=# SELECT encode(
    digest('Hello, World!', 'sha512'),
    'hex'
) AS sha512_hash;
postgres=# -- Same input always produces same hash:
postgres=# SELECT encode(digest('password123', 'sha256'), 'hex');
postgres=# -- ef92b778bafe771e89245b89ecbc08a44a...
postgres=# SELECT encode(digest('password123', 'sha256'), 'hex');
postgres=# -- ef92b778bafe771e89245b89ecbc08a44a...
postgres=# -- Identical!
postgres=# -- Verify data integrity:
postgres=# SELECT encode(digest(data, 'sha256'), 'hex') AS checksum
postgres-# FROM attachments WHERE id = 1;
```

### hmac() — Keyed Hashing
**Explanation:** HMAC adds a secret key to the hash. This is useful for verifying both integrity and authenticity — only someone with the key can produce the correct HMAC.

```sql
postgres=# -- HMAC with a secret key:
postgres=# SELECT encode(
    hmac('message', 'secret-key', 'sha256'),
    'hex'
) AS hmac_hash;
postgres=# -- a key-dependent hash — different key = different hash
postgres=# -- Use case: API request signing
postgres=# -- Server and client share a secret key
postgres=# -- Client sends: message + HMAC(message, key)
postgres=# -- Server recalculates HMAC and compares
postgres=# -- Without the key, attacker cannot forge the HMAC
postgres=# SELECT encode(
    hmac('message', 'wrong-key', 'sha256'),
    'hex'
) AS wrong_hmac;
postgres=# -- Completely different hash!
```

### crypt() & gen_salt() — Password Hashing (bcrypt)
**Explanation:** For password storage, pgcrypto provides the crypt and gen_salt functions. These use bcrypt by default — the industry standard for password hashing. Bcrypt automatically handles salting, which means the same password produces a different hash every time.

```sql
postgres=# -- Hash a password with bcrypt:
postgres=# SELECT crypt('mypassword', gen_salt('bf'));
postgres=# -- $2a$06$Rq7v7oNxSKxK3v5x/pLjYe...
postgres=# -- Hash again — different result! (random salt)
postgres=# SELECT crypt('mypassword', gen_salt('bf'));
postgres=# -- $2a$06$Tj2k8mLp5xR7k1oYhNwZUO...
postgres=# -- Verify a password:
postgres=# SELECT (
    crypt('mypassword', stored_hash) = stored_hash
) AS password_matches;
postgres=# -- Practical: store hashed password in users table:
postgres=# CREATE TABLE app_users (
    id serial PRIMARY KEY,
    username text UNIQUE NOT NULL,
    password_hash text NOT NULL
);
postgres=# -- Register:
postgres=# INSERT INTO app_users (username, password_hash)
postgres-# VALUES ('alice', crypt('SecurePass1!', gen_salt('bf', 10)));
postgres=# -- Login check:
postgres=# SELECT id, username FROM app_users
postgres-# WHERE username = 'alice'
postgres-# AND password_hash = crypt('SecurePass1!', password_hash);
```

### Symmetric Encryption — encrypt() / decrypt()
**Explanation:** Now symmetric encryption — encrypt and decrypt with the same key. The encrypt function takes data, a key, and an algorithm. The decrypt function reverses it. Use AES for production.

```sql
postgres=# -- Encrypt with AES:
postgres=# SELECT encrypt(
    'Secret credit card: 4111-1111-1111-1111',
    'my-encryption-key',
    'aes'
) AS encrypted_data;
postgres=# -- Returns: bytea (binary blob)
postgres=# -- Decrypt:
postgres=# SELECT convert_from(
    decrypt(
        encrypted_data,
        'my-encryption-key',
        'aes'
    ),
    'UTF8'
) AS decrypted;
postgres=# -- Secret credit card: 4111-1111-1111-1111
postgres=# -- With initialization vector (more secure):
postgres=# SELECT encrypt_iv(
    'Sensitive data'::bytea,
    'my-encryption-key'::bytea,
    'random-iv-value!'::bytea,  -- 16 bytes for AES
    'aes'
);
postgres=# -- Supported algorithms: aes, bf (Blowfish), 3des
```

### PGP Symmetric Encryption
**Explanation:** PGP encryption is also available for more complex scenarios. pgp_sym_encrypt uses PGP symmetric encryption with a passphrase. The output is ASCII-armored — safe to store as text.

```sql
postgres=# -- PGP symmetric encrypt (passphrase-based):
postgres=# SELECT pgp_sym_encrypt(
    'My secret message',
    'strong-passphrase-here'
) AS pgp_encrypted;
postgres=# -- Returns: bytea (PGP-formatted)
postgres=# -- Decrypt:
postgres=# SELECT pgp_sym_decrypt(
    pgp_encrypted,
    'strong-passphrase-here'
) AS decrypted;
postgres=# -- My secret message
postgres=# -- With options (compress + cipher):
postgres=# SELECT pgp_sym_encrypt(
    'My secret message',
    'passphrase',
    'compress-algo=1, cipher-algo=aes256'
);
postgres=# -- Advantage over raw encrypt():
postgres=# -- PGP format includes metadata, compression,
postgres=# -- and standardized key derivation
```

### Practical: Encrypted Column
**Explanation:** Let us build a practical example — encrypting sensitive columns in a table. We will encrypt email addresses so they are protected at rest.

```sql
postgres=# CREATE TABLE sensitive_data (
    id serial PRIMARY KEY,
    name text NOT NULL,
    encrypted_email bytea NOT NULL,
    encrypted_ssn bytea
);
postgres=# -- Insert with encryption:
postgres=# INSERT INTO sensitive_data (name, encrypted_email, encrypted_ssn)
postgres-# VALUES (
    'Alice Smith',
    pgp_sym_encrypt('alice@example.com', 'app-secret-key'),
    pgp_sym_encrypt('123-45-6789', 'app-secret-key')
);
postgres=# -- Read encrypted (gibberish):
postgres=# SELECT name, encrypted_email FROM sensitive_data;
postgres=# -- Alice Smith | \xc30d04070302...
postgres=# -- Decrypt to read:
postgres=# SELECT name,
    pgp_sym_decrypt(encrypted_email, 'app-secret-key') AS email,
    pgp_sym_decrypt(encrypted_ssn, 'app-secret-key') AS ssn
postgres-# FROM sensitive_data;
postgres=# -- Alice Smith | alice@example.com | 123-45-6789
```

### Random Data Generation
**Explanation:** gen_random_bytes generates cryptographically secure random bytes. gen_random_uuid generates a random version 4 UUID. These are useful for tokens, API keys, and unique identifiers.

```sql
postgres=# -- Generate random bytes:
postgres=# SELECT encode(gen_random_bytes(16), 'hex') AS random_hex;
postgres=# -- a7f3b2c1d4e5f6a7b8c9d0e1f2a3b4c5
postgres=# -- Generate random bytes as base64 (good for tokens):
postgres=# SELECT encode(gen_random_bytes(32), 'base64') AS api_token;
postgres=# -- p7M8xK2R3vY1wZ0qN5bH6jD4mF9aG8cE...
postgres=# -- Generate UUID v4 (also available without pgcrypto in PG 13+):
postgres=# SELECT gen_random_uuid();
postgres=# -- 550e8400-e29b-41d4-a716-446655440000
postgres=# -- Practical: generate API keys:
postgres=# CREATE TABLE api_keys (
    id serial PRIMARY KEY,
    user_id int NOT NULL,
    key_hash text NOT NULL,  -- store hash, not key!
    created_at timestamptz DEFAULT now()
);
postgres=# -- Generate key, hash it, store the hash:
postgres=# -- Give the raw key to the user once
postgres=# -- Only store the hash in the database
```

### Beginner Trap: digest() vs crypt() for Passwords
**Explanation:** A common beginner trap — using digest or SHA-256 for password hashing instead of crypt with bcrypt. Plain hashes are extremely fast to brute-force. Bcrypt is deliberately slow and includes automatic salting.

```sql
postgres=# -- WRONG: SHA-256 for passwords (too fast to crack!)
postgres=# SELECT encode(digest('password123', 'sha256'), 'hex');
postgres=# -- Same hash every time → rainbow table vulnerable
postgres=# -- GPU can test billions per second
postgres=# -- RIGHT: bcrypt with crypt() (deliberately slow)
postgres=# SELECT crypt('password123', gen_salt('bf', 10));
postgres=# -- Different hash every time (random salt)
postgres=# -- Cost factor 10 → ~100ms per hash
postgres=# -- Brute-force: ~10 attempts per second per GPU
postgres=# -- The difference:
postgres=# -- SHA-256:  10,000,000,000 guesses/second (GPU)
postgres=# -- bcrypt-10:           10 guesses/second (GPU)
postgres=# -- That is a BILLION times slower to crack!
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: digest() vs crypt() for Passwords
A common beginner trap — using digest or SHA-256 for password hashing instead of crypt with bcrypt. Plain hashes are extremely fast to brute-force. Bcrypt is deliberately slow and includes automatic salting.

```sql
-- WRONG: SHA-256 for passwords (too fast to crack!)
SELECT encode(digest('password123', 'sha256'), 'hex');
-- Same hash every time → rainbow table vulnerable
-- GPU can test billions per second
-- RIGHT: bcrypt with crypt() (deliberately slow)
SELECT crypt('password123', gen_salt('bf', 10));
-- Different hash every time (random salt)
-- Cost factor 10 → ~100ms per hash
-- Brute-force: ~10 attempts per second per GPU
-- The difference:
-- SHA-256:  10,000,000,000 guesses/second (GPU)
-- bcrypt-10:           10 guesses/second (GPU)
-- That is a BILLION times slower to crack!
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. pgcrypto is a trusted extension for cryptographic operations. Use digest for data integrity hashes — SHA-256 or higher. Use crypt with gen_salt for password hashing — always bcrypt with cost 10 or higher. Use encrypt or pgp_sym_encrypt for column encryption — AES-256 recommended. Use gen_random_bytes for tokens and random data. Store encryption keys outside the database. Never use MD5 or SHA for passwords. In the next class, we learn uuid-ossp and gen_random_uuid for generating unique identifiers.

- **Trusted extension — no restart needed**
- **digest(): hash data (SHA-256, SHA-512)**
- **hmac(): keyed hash for integrity + authenticity**
- **crypt() + gen_salt('bf', 10): bcrypt password hashing**
- **encrypt() / decrypt(): symmetric encryption (AES)**
- **pgp_sym_encrypt/decrypt: PGP symmetric encryption**
- **gen_random_bytes(): cryptographically secure random data**
- **gen_random_uuid(): random UUID v4**
- **Always bcrypt for passwords, never plain SHA**
- **Store encryption keys outside the database**
- **Next: uuid-ossp & gen_random_uuid**


---

## 8. Downloadable SQL Script Instructions

Every command demonstrated in this video is compiled into the companion `materials.sql` file.

To execute it directly in PostgreSQL:

```bash
# From your command line:
psql -U postgres -d postgres -f materials.sql

# Or from inside psql prompt:
postgres=# \i materials.sql
```
