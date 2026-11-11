# Advisory Locks & Concurrency Patterns
**Series:** PostgreSQL Mastery | **Phase:** Phase 13: Transactions & Concurrency | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover advisory locks and practical concurrency patterns. Advisory locks are application-defined locks that PostgreSQL manages for you — they are not tied to any table or row. They are perfect for coordinating between application processes: ensuring only one worker processes a specific task, or preventing duplicate cron jobs. We will also cover real-world concurrency patterns. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Advisory Locks — Application-Level Coordination
Advisory locks are voluntary locks. Unlike row or table locks, PostgreSQL does not enforce them — your application decides what they mean. You lock an integer key, and any other session that tries to lock the same key must wait or is told it cannot proceed. Use them to coordinate between processes: only one cron job runs at a time, only one worker processes a specific customer, or a deployment lock prevents two deploys from overlapping.

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | Voluntary locks on integer keys (not tied to tables) |
| **Session-level** | pg_advisory_lock(key) — held until session ends or unlock |
| **Transaction-level** | pg_advisory_xact_lock(key) — released at COMMIT/ROLLBACK |
| **Try lock** | pg_try_advisory_lock(key) — returns true/false, never waits |
| **Use case** | Singleton cron jobs, per-entity processing, deploy locks |

**Notes:**
- Key is a BIGINT — use a hash of entity name/ID
- Advisory locks do NOT lock any rows or tables

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Real-World Concurrency Patterns
Here are practical concurrency patterns you will use in real applications. The job queue pattern uses SKIP LOCKED to let multiple workers grab jobs without blocking each other. The optimistic locking pattern uses a version column to detect concurrent changes. The idempotent upsert uses INSERT ON CONFLICT to handle duplicate requests safely. Each solves a different concurrency problem.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Here** | practical concurrency patterns you will use in real applications |
| **The job queue pattern** | SKIP LOCKED to let multiple workers grab jobs without blocking each other |
| **The optimistic locking pattern** | a version column to detect concurrent changes |
| **The idempotent upsert** | INSERT ON CONFLICT to handle duplicate requests safely |

### Practice Exercises
Practice exercises: acquire and release advisory locks, use pg_try_advisory_lock for a singleton pattern, implement optimistic locking with a version column, create an idempotent upsert, and build a job queue with SKIP LOCKED.

- 1. pg_advisory_lock(100) in session A, try in session B → waits
- 2. pg_try_advisory_lock(200) → returns true/false
- 3. pg_advisory_xact_lock(300) → released at COMMIT
- 4. Optimistic locking: version column, concurrent updates
- 5. Idempotent upsert: INSERT ON CONFLICT DO NOTHING
- 6. Job queue: SELECT ... FOR UPDATE SKIP LOCKED
- 7. Monitor: SELECT * FROM pg_locks WHERE locktype='advisory'


---

## 3. Hands-On Commands & psql Output

### Session-Level Advisory Locks
**Explanation:** Session-level advisory locks persist until you explicitly unlock them or the session disconnects. They are NOT released by COMMIT or ROLLBACK. Use pg_advisory_lock to acquire — it blocks if the lock is held. Use pg_try_advisory_lock to check without waiting — it returns true if acquired, false if already held. Use pg_advisory_unlock to release.

```sql
-- Session A: acquire advisory lock (key = 12345)
[A] practice=# SELECT pg_advisory_lock(12345);
 pg_advisory_lock
------------------
                  
-- Lock acquired!

-- Session B: tries to acquire same lock → WAITS
[B] practice=# SELECT pg_advisory_lock(12345);
-- (hanging... waiting for A to release)

-- Session A: release the lock
[A] practice=# SELECT pg_advisory_unlock(12345);
 pg_advisory_unlock
--------------------
 t

-- Session B: immediately acquires the lock
 pg_advisory_lock
------------------
                  
-- B now holds the lock
```

### TRY Lock — Non-Blocking Check
**Explanation:** pg_try_advisory_lock is the non-blocking version. It returns true if the lock was acquired, false if it is already held. This is perfect for singleton processes — try to acquire the lock, if it fails, exit immediately because another instance is already running. No waiting, no blocking, just a clean check.

```sql
-- Singleton cron job pattern
practice=# SELECT pg_try_advisory_lock(99999);
 pg_try_advisory_lock
----------------------
 t    -- Got it! We're the only instance

-- Another session tries:
practice=# SELECT pg_try_advisory_lock(99999);
 pg_try_advisory_lock
----------------------
 f    -- Someone else has it! Exit gracefully

-- Two-key advisory lock (for entity-specific locks)
practice=# SELECT pg_advisory_lock(1, 42);
-- Lock key (1, 42) = e.g., entity_type=1, entity_id=42

practice=# SELECT pg_advisory_unlock(1, 42);

-- Transaction-level: auto-released at COMMIT/ROLLBACK
-- BEGIN; SELECT pg_advisory_xact_lock(12345);
-- ... do work ... COMMIT; -- lock auto-released
```

### Optimistic Locking Pattern
**Explanation:** Optimistic locking is a pattern where you add a version column to your table. When you read a row, you note its version. When you update, you include WHERE version = the_version_you_read. If someone else changed it in between, your update affects zero rows — you know a conflict happened and can retry or notify the user. No locks held during the read — just a check at write time.

```sql
-- Table with version column
practice=# CREATE TABLE products (
  id      INT PRIMARY KEY,
  name    VARCHAR(100),
  price   NUMERIC(10,2),
  version INT DEFAULT 1
);
practice=# INSERT INTO products VALUES (1, 'Widget', 29.99, 1);

-- User A reads: version = 1
-- User B reads: version = 1

-- User A updates with version check:
practice=# UPDATE products SET price = 34.99, version = version + 1
WHERE id = 1 AND version = 1;
UPDATE 1  -- Success! Version now = 2

-- User B tries with stale version:
practice=# UPDATE products SET price = 39.99, version = version + 1
WHERE id = 1 AND version = 1;
UPDATE 0  -- 0 rows! Version changed → conflict detected
```

### Idempotent Upsert — Safe Duplicates
**Explanation:** The idempotent upsert with INSERT ON CONFLICT handles duplicate requests safely. If a duplicate request comes in — same order ID, same payment — instead of failing with a constraint violation, it either does nothing or updates the existing row. This is critical for systems where the same request might be sent twice — payment webhooks, API retries, or message queues with at-least-once delivery.

```sql
-- Payment records: idempotent by payment_id
practice=# CREATE TABLE payments (
  payment_id VARCHAR(50) PRIMARY KEY,
  amount     NUMERIC(10,2),
  status     VARCHAR(20) DEFAULT 'processed',
  created_at TIMESTAMP DEFAULT NOW()
);

-- First request: inserts
practice=# INSERT INTO payments (payment_id, amount)
VALUES ('PAY-001', 99.99)
ON CONFLICT (payment_id) DO NOTHING;
INSERT 0 1

-- Duplicate request: silently ignored
practice=# INSERT INTO payments (payment_id, amount)
VALUES ('PAY-001', 99.99)
ON CONFLICT (payment_id) DO NOTHING;
INSERT 0 0  -- 0 rows inserted, no error!

-- Or update on conflict:
-- ON CONFLICT (payment_id) DO UPDATE
--   SET status = 'reprocessed';
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap the entire Transactions and Concurrency phase. BEGIN, COMMIT, ROLLBACK wrap statements into atomic units. ACID guarantees correctness. SAVEPOINT allows partial rollback. Read Committed is the default isolation level — Repeatable Read and Serializable provide stronger guarantees. Row locks are automatic; SELECT FOR UPDATE locks explicitly. Deadlocks are detected and one transaction is killed. Advisory locks coordinate application processes. SKIP LOCKED enables job queues, optimistic locking detects conflicts, and upserts handle duplicates. This completes the Transactions phase! In the next phase, we start PL/pgSQL Programming — functions, procedures, control flow, and more. See you there!

- **BEGIN/COMMIT/ROLLBACK: atomic operations**
- **SAVEPOINT: partial rollback inside transaction**
- **Read Committed → Repeatable Read → Serializable**
- **Row locks: automatic, readers never blocked**
- **Deadlocks: PG detects, lock in consistent order**
- **Advisory locks: pg_advisory_lock(key) for coordination**
- **SKIP LOCKED: job queue pattern**
- **Optimistic locking: version column for conflict detection**


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
