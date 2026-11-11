# Data Encryption & Key Management
**Series:** PostgreSQL Mastery | **Phase:** Phase 27: Security | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we encrypted the connection between client and server using SSL/TLS. But what about the data sitting on disk? If someone steals the hard drive, copies a backup file, or gains shell access to the server, they can read your data directly — even without connecting to PostgreSQL. Today we cover data encryption — protecting sensitive data at rest. We will use pgcrypto for column-level encryption and discuss full-disk encryption for the data directory. Let us begin.

### The Problem — Data Readable on Disk
A hospital database stores patient records including social security numbers, medical diagnoses, and insurance details. The data is behind firewalls, the connections are encrypted with SSL, and authentication uses SCRAM. One night, an attacker gains shell access to the server through a vulnerability in another application on the same machine. They do not need the PostgreSQL password — they just copy the data directory files and read them with a hex editor. Or they grab a backup file from the network share. All the patient data is in plain text on disk. HIPAA violation. Millions in fines. This is why you need encryption at rest.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand SSL/TLS from the previous class and know how to install extensions from Phase 26. Recap — we set up SSL to encrypt data in transit. But data at rest — files on disk, backups, WAL files — is still in plain text. A stolen backup tape or a compromised server reveals everything. Encryption at rest is the solution.

- Prerequisite: SSL/TLS configuration (previous class)
- Prerequisite: Installing extensions (Phase 26)
- Recap: SSL encrypts data IN TRANSIT (on the wire)
- Problem: Data AT REST (disk, backups, WAL) is still plain text
- Now: Encrypting data where it lives — columns and disks

### The Problem — Data Readable on Disk
A hospital database stores patient records including social security numbers, medical diagnoses, and insurance details. The data is behind firewalls, the connections are encrypted with SSL, and authentication uses SCRAM. One night, an attacker gains shell access to the server through a vulnerability in another application on the same machine. They do not need the PostgreSQL password — they just copy the data directory files and read them with a hex editor. Or they grab a backup file from the network share. All the patient data is in plain text on disk. HIPAA violation. Millions in fines. This is why you need encryption at rest.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Scenario** | Hospital database with SSN, diagnoses, insurance info |
| **Attack** | Attacker gets shell access — copies data directory files directly |
| **Result** | All data readable in plain text — no PostgreSQL password needed |
| **Also At Risk** | Backup files, WAL archives, pg_dump output, temp files |
| **Compliance** | HIPAA, PCI-DSS, GDPR all require encryption of sensitive data at rest |

### Three Levels of Encryption at Rest
There are three levels of encryption at rest. Column-level encryption — you encrypt individual columns using pgcrypto. Only the sensitive columns are encrypted, and the application decrypts them when needed. This is the most granular but adds complexity. Full-disk encryption — the entire file system is encrypted at the OS level using LUKS on Linux or BitLocker on Windows. Everything is encrypted transparently. Transparent Data Encryption, or TDE — the database engine encrypts data pages before writing to disk. PostgreSQL 16 does not have built-in TDE, but some forks like EDB Postgres Advanced Server do. Let us focus on what works in standard PostgreSQL 16.

| Term | Meaning / Explanation |
| :--- | :--- |
| **There** | three levels of encryption at rest |
| **Only the sensitive columns** | encrypted, and the application decrypts them when needed |
| **This** | the most granular but adds complexity |
| **Everything** | encrypted transparently |
| **Let us focus on what** | in standard PostgreSQL 16 |

### Key Management — Where to Store the Key
Key management is the hardest part of encryption. The encryption key must be available when the application needs to decrypt, but it must never be stored in the database itself. If the key is in the same place as the encrypted data, the encryption is useless — like locking a safe and taping the combination to the door. Here are the key storage options, from worst to best.

| BAD (Never Do This) | GOOD (Production Approaches) |
| :--- | :--- |
| Hardcoded in SQL queries | Application passes key at runtime |
| Stored in a database table | Environment variable on app server |
| In the application source code | HashiCorp Vault or AWS KMS |
| In a config file on the DB server | Azure Key Vault or GCP Cloud KMS |
| In a .env file committed to git | Hardware Security Module (HSM) |

### Support This Free Course
If you are learning from this course, here is how you can support the work. Like this video. Share it with someone learning PostgreSQL. Subscribe and hit the bell icon. Download today's class materials from the link in the description. And if this free course is helping you, consider supporting through the donation link. Now let us cover key rotation and full-disk encryption.

- Like this video — helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + bell icon for new classes
- Download class materials (link in description)
- Support this free course: donation link in description

### Column-Level vs Full-Disk Encryption
Let us compare column-level and full-disk encryption. Column-level encryption with pgcrypto gives you granular control — you choose exactly which columns to encrypt and which keys to use. But it adds application complexity, you cannot search encrypted columns directly, and it has a performance cost for every encrypt and decrypt operation. Full-disk encryption is transparent to the application — no code changes needed. It protects everything including temp files and WAL. But it does not protect against SQL injection or a logged-in attacker — once the OS is booted and the disk is mounted, the data is readable.

| Column-Level (pgcrypto) | Full-Disk (LUKS) |
| :--- | :--- |
| Granular: encrypt specific columns | Transparent: all files encrypted |
| Different keys per column/tenant | One key for entire partition |
| Protects against DB-level access | Protects against physical theft |
| Application must handle keys | No application changes needed |
| Cannot search encrypted columns | All queries work normally |
| Performance cost per operation | Minimal performance impact |
| Compliance: field-level protection | Compliance: storage-level protection |

### Practice Exercises
Here are your practice exercises. One — install pgcrypto and create a table with encrypted columns. Insert and retrieve data using pgp_sym_encrypt and pgp_sym_decrypt. Two — implement the searchable encryption pattern using HMAC hashes for lookups. Three — perform key rotation: decrypt with the old key and re-encrypt with a new key in a single transaction. Four — encrypt a pg_dump backup with GPG and restore it. Five — if you have a test Linux VM, set up LUKS encryption on a partition and move a PostgreSQL data directory onto it.

- 1. Create encrypted columns with pgp_sym_encrypt/decrypt
- 2. Implement searchable encryption with HMAC hash index
- 3. Rotate encryption keys in a single transaction
- 4. Encrypt a pg_dump backup with GPG, then restore it
- 5. (Advanced) Set up LUKS encryption for PG data directory

### Encryption Performance Impact
Performance impact is something you need to understand. Column-level encryption adds CPU overhead for every encrypt and decrypt operation. On modern hardware, AES-256 encryption can process about 1 to 3 gigabytes per second, so the impact on individual queries is small. But if you are decrypting thousands of rows in a report, it adds up. Full-disk encryption with AES-NI hardware support has negligible overhead — typically 1 to 5 percent.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Performance impact** | something you need to understand |
| **Column-level encryption** | CPU overhead for every encrypt and decrypt operation |
| **But if you** | decrypting thousands of rows in a report, it adds up |
| **Full-disk encryption with AES-NI hardware** | has negligible overhead — typically 1 to 5 percent |


---

## 3. Hands-On Commands & psql Output

### Setup — Encrypted Patients Table
**Explanation:** pgcrypto is a built-in PostgreSQL extension we introduced in Phase 26. Today we use it specifically for encrypting sensitive columns. We already know the basics — now we apply it to a real scenario. Let us create a patients table where the social security number and diagnosis columns are encrypted. The patient name stays in plain text for searching.

```sql
postgres=# CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION

postgres=# CREATE TABLE patients (
postgres(#     id SERIAL PRIMARY KEY,
postgres(#     name TEXT NOT NULL,
postgres(#     ssn_encrypted BYTEA,         -- encrypted SSN
postgres(#     diagnosis_encrypted BYTEA,   -- encrypted diagnosis
postgres(#     created_at TIMESTAMPTZ DEFAULT now()
postgres(# );
CREATE TABLE

-- Encrypted columns use BYTEA type (binary data)
-- Plain text columns (name) can still be searched/indexed
```

### Inserting Encrypted Data
**Explanation:** Now let us insert data with symmetric encryption using PGP_SYM_ENCRYPT. This function encrypts data with a passphrase using AES-256. The passphrase acts as the encryption key. Anyone who knows the passphrase can decrypt the data. In production, the passphrase should never be stored in the database — it should come from the application, an environment variable, or a key management service.

```sql
postgres=# INSERT INTO patients (name, ssn_encrypted, diagnosis_encrypted)
postgres-# VALUES (
postgres(#     'Alice Johnson',
postgres(#     pgp_sym_encrypt('123-45-6789', 'my-secret-key-2026'),
postgres(#     pgp_sym_encrypt('Type 2 Diabetes', 'my-secret-key-2026')
postgres(# );
INSERT 0 1

postgres=# INSERT INTO patients (name, ssn_encrypted, diagnosis_encrypted)
postgres-# VALUES (
postgres(#     'Bob Smith',
postgres(#     pgp_sym_encrypt('987-65-4321', 'my-secret-key-2026'),
postgres(#     pgp_sym_encrypt('Hypertension', 'my-secret-key-2026')
postgres(# );
INSERT 0 1
```

### Reading Encrypted Data — With and Without Key
**Explanation:** Now let us prove the encryption works. When you SELECT the encrypted columns without decrypting, you see binary gibberish. The data is unreadable without the key. When you use pgp_sym_decrypt with the correct key, you get the original data back. If you use the wrong key, you get an error.

```sql
-- Without decryption: just binary data
postgres=# SELECT name, ssn_encrypted FROM patients;
     name      |                 ssn_encrypted
---------------+--------------------------------------------
 Alice Johnson | \xc30d04070302d8a1b3c7e2f9a8b6...
 Bob Smith     | \xc30d04070302f4e5d6c7b8a99087...

-- With correct key: original data restored
postgres=# SELECT name,
postgres-#   pgp_sym_decrypt(ssn_encrypted, 'my-secret-key-2026') AS ssn,
postgres-#   pgp_sym_decrypt(diagnosis_encrypted, 'my-secret-key-2026') AS diagnosis
postgres-# FROM patients;
     name      |     ssn      |    diagnosis
---------------+--------------+-----------------
 Alice Johnson | 123-45-6789  | Type 2 Diabetes
 Bob Smith     | 987-65-4321  | Hypertension

-- Wrong key: error
ERROR:  Wrong key or corrupt data
```

### Searchable Encryption Pattern
**Explanation:** An important limitation: you cannot search or index encrypted columns. The encrypted bytes are different every time, even for the same input, because pgcrypto uses random salt. So you cannot do WHERE ssn_encrypted = encrypt(value). For searchable encryption, you need a pattern: store a hash of the value alongside the encrypted data. The hash allows exact-match lookups, while the encrypted column stores the actual value. Use a keyed hash like HMAC so the hash cannot be reversed.

```sql
postgres=# ALTER TABLE patients ADD COLUMN ssn_hash TEXT;
ALTER TABLE

-- Store HMAC hash for lookups (one-way, keyed)
postgres=# UPDATE patients SET ssn_hash = encode(
postgres-#   hmac(pgp_sym_decrypt(ssn_encrypted, 'my-secret-key-2026'),
postgres-#        'hmac-lookup-key', 'sha256'), 'hex');
UPDATE 2

-- Create index on hash column
postgres=# CREATE INDEX idx_patients_ssn_hash ON patients (ssn_hash);
CREATE INDEX

-- Now you can search by SSN without decrypting:
postgres=# SELECT name FROM patients
postgres-# WHERE ssn_hash = encode(hmac('123-45-6789', 'hmac-lookup-key', 'sha256'), 'hex');
     name
---------------
 Alice Johnson
```

### Key Rotation — Re-encrypt with New Key
**Explanation:** Key rotation means changing the encryption key periodically. Compliance standards typically require rotation every 90 days to one year. The process is: decrypt all data with the old key, re-encrypt with the new key, and update the stored data. This must be done in a transaction so the data is never left in an inconsistent state.

```sql
postgres=# BEGIN;
BEGIN

-- Decrypt with OLD key, re-encrypt with NEW key
postgres=*# UPDATE patients SET
postgres-*#   ssn_encrypted = pgp_sym_encrypt(
postgres-*#     pgp_sym_decrypt(ssn_encrypted, 'old-key-2026'),
postgres-*#     'new-key-2027'),
postgres-*#   diagnosis_encrypted = pgp_sym_encrypt(
postgres-*#     pgp_sym_decrypt(diagnosis_encrypted, 'old-key-2026'),
postgres-*#     'new-key-2027');
UPDATE 2

postgres=*# COMMIT;
COMMIT
-- All data now encrypted with new key
-- Old key can be retired after verifying
```

### Full-Disk Encryption with LUKS
**Explanation:** Full-disk encryption protects everything on the file system — not just specific columns, but the entire data directory, WAL files, temp files, and swap space. On Linux, LUKS with dm-crypt is the standard. You encrypt the partition where the PostgreSQL data directory lives. PostgreSQL does not know or care — it reads and writes files normally, and the OS handles encryption and decryption transparently. The key is provided at boot time or when mounting the encrypted partition.

```sql
# Format partition with LUKS encryption
$ sudo cryptsetup luksFormat /dev/sdb1
WARNING: This will overwrite data on /dev/sdb1 irrevocably.
Are you sure? (Type 'yes' in uppercase): YES
Enter passphrase for /dev/sdb1:

# Open the encrypted partition
$ sudo cryptsetup luksOpen /dev/sdb1 pgdata_crypt
Enter passphrase for /dev/sdb1:

# Create filesystem and mount
$ sudo mkfs.ext4 /dev/mapper/pgdata_crypt
$ sudo mount /dev/mapper/pgdata_crypt /var/lib/postgresql/16/main

# PostgreSQL data directory is now on encrypted disk
# Encryption/decryption is transparent to PostgreSQL
```

### Encrypting Backups
**Explanation:** Do not forget about backup encryption. Your pg_dump output files, pg_basebackup archives, and WAL archive files also contain your data in plain text. Encrypt backups with GPG or use backup tools that support encryption natively. pgBackRest supports built-in encryption with a passphrase. For pg_dump, pipe the output through gpg.

```sql
# pg_dump → GPG encryption
$ pg_dump -Fc mydb | gpg --symmetric --cipher-algo AES256 \
>   -o /backups/mydb_$(date +%Y%m%d).dump.gpg
Enter passphrase:

# Decrypt and restore
$ gpg --decrypt /backups/mydb_20261104.dump.gpg | pg_restore -d mydb

# pgBackRest with built-in encryption
# In /etc/pgbackrest/pgbackrest.conf:
# [global]
# repo1-cipher-type=aes-256-cbc
# repo1-cipher-pass=your-backup-encryption-key

# All backups and WAL archives are now encrypted automatically
```

### Beginner Traps — Encryption Mistakes
**Explanation:** Beginner trap number one — storing the encryption key in the same database as the encrypted data. This defeats the entire purpose. If an attacker can read your tables, they can read the key table too. Always store keys externally. Trap number two — logging decrypted values. If log_statement is set to all, your decrypt queries appear in the PostgreSQL log with the key parameter visible. Use log_statement = ddl or none for applications that handle encrypted data. Trap number three — forgetting about pg_stat_statements. This extension can capture your decrypt queries with the key parameter. Disable it or filter sensitive queries.

```sql
-- Trap 1: Key stored in the database
-- BAD: CREATE TABLE keys (name TEXT, key TEXT);
-- Attacker reads keys table → decrypts everything

-- Trap 2: Key visible in PostgreSQL logs
-- With log_statement = 'all':
LOG: statement: SELECT pgp_sym_decrypt(data, 'my-secret-key')
--                                          ^^^^^^^^^^^^^^^^
-- Your key is now in the log file!

-- Fix: Set for the app user:
postgres=# ALTER ROLE app_user SET log_statement = 'ddl';
ALTER ROLE

-- Trap 3: pg_stat_statements captures queries with keys
-- Fix: Use $1 parameters, not literal keys in queries
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Encryption Mistakes
Beginner trap number one — storing the encryption key in the same database as the encrypted data. This defeats the entire purpose. If an attacker can read your tables, they can read the key table too. Always store keys externally. Trap number two — logging decrypted values. If log_statement is set to all, your decrypt queries appear in the PostgreSQL log with the key parameter visible. Use log_statement = ddl or none for applications that handle encrypted data. Trap number three — forgetting about pg_stat_statements. This extension can capture your decrypt queries with the key parameter. Disable it or filter sensitive queries.

```sql
-- Trap 1: Key stored in the database
-- BAD: CREATE TABLE keys (name TEXT, key TEXT);
-- Attacker reads keys table → decrypts everything

-- Trap 2: Key visible in PostgreSQL logs
-- With log_statement = 'all':
LOG: statement: SELECT pgp_sym_decrypt(data, 'my-secret-key')
--                                          ^^^^^^^^^^^^^^^^
-- Your key is now in the log file!

-- Fix: Set for the app user:
ALTER ROLE app_user SET log_statement = 'ddl';
ALTER ROLE

-- Trap 3: pg_stat_statements captures queries with keys
-- Fix: Use $1 parameters, not literal keys in queries
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. Column-level encryption with pgcrypto protects specific sensitive fields — SSN, credit cards, medical data. Use pgp_sym_encrypt and pgp_sym_decrypt with keys stored outside the database. Full-disk encryption with LUKS protects the entire data directory transparently. Always encrypt backups. Never store encryption keys in the database. Watch out for keys appearing in logs and pg_stat_statements. For compliance, use both column-level and full-disk encryption together.

- **pgcrypto: pgp_sym_encrypt/decrypt for sensitive columns (BYTEA)**
- **Keys NEVER in the database — use Vault, KMS, or app environment**
- **Searchable encryption: HMAC hash column + index for lookups**
- **Key rotation: decrypt + re-encrypt in a single transaction**
- **Full-disk: LUKS encrypts everything transparently (1-5% overhead)**
- **ALWAYS encrypt backups (GPG or pgBackRest cipher)**
- **Watch logs: set log_statement = ddl for app roles**
- **Compliance: column + disk encryption for HIPAA/PCI/GDPR**


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
