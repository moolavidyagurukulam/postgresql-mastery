# Dead Tuples, Bloat & VACUUM
**Series:** PostgreSQL Mastery | **Phase:** Phase 19: Vacuum & Maintenance | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! We are now entering Phase 19 — Vacuum and Maintenance. This is where we learn how to keep PostgreSQL healthy over time. Every database that handles updates and deletes will grow bloated without proper maintenance. In this class, we start with the root cause — dead tuples — and then learn VACUUM, the tool that cleans them up. Let us begin.

### The Filing Cabinet Problem
Imagine a filing cabinet. When you update a document, you do not erase the old one — you write a new version and put it in front. The old version stays in the drawer. When you delete a document, you mark it as removed, but it stays in the drawer. After months of updates and deletes, your cabinet is full of old, useless paper. Finding anything takes forever because you are flipping through dead documents. That is exactly what happens inside PostgreSQL.

### Why Dead Tuples Exist — MVCC in Action
Why does PostgreSQL keep old versions instead of updating in place? Because of MVCC. When you run an UPDATE, another transaction might still be reading the old version. PostgreSQL cannot just overwrite it. So it creates a new tuple with the updated data, and the old tuple stays until nobody needs it anymore. The same logic applies to DELETE — the row is marked invisible but physically remains. This is brilliant for concurrency — readers never block writers. But it creates garbage that must be cleaned up.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand MVCC — multi-version concurrency control — from our earlier architecture classes. You should also know what transactions are and how UPDATE and DELETE work at the SQL level. Quick recap from Phase 18 — we learned backup and recovery, which protects your data from disasters. Now we protect your database from a slower, sneakier problem: bloat. It happens silently, and if you ignore it, your fast database gradually becomes painfully slow.

- Prerequisite: MVCC (multi-version concurrency control)
- Prerequisite: How UPDATE and DELETE work in SQL
- Recap: Phase 18 covered backup, recovery & disaster planning
- Now: Protecting your database from silent performance decay

### The Filing Cabinet Problem
Imagine a filing cabinet. When you update a document, you do not erase the old one — you write a new version and put it in front. The old version stays in the drawer. When you delete a document, you mark it as removed, but it stays in the drawer. After months of updates and deletes, your cabinet is full of old, useless paper. Finding anything takes forever because you are flipping through dead documents. That is exactly what happens inside PostgreSQL.

| Term | Meaning / Explanation |
| :--- | :--- |
| **UPDATE a row** | PostgreSQL creates a NEW version, marks the OLD version as invisible |
| **DELETE a row** | PostgreSQL marks the row as invisible — does NOT remove it from disk |
| **Dead Tuple** | An old row version that no transaction can ever see again |
| **Bloat** | Disk space wasted by accumulated dead tuples |

**Notes:**
- MVCC requires keeping old versions while transactions might still need them
- Once ALL transactions that could see the old version are done, it becomes dead

### Why Bloat Hurts Performance
Why should you care about bloat? Three reasons. First, wasted disk space — your table is much larger than it needs to be. Second, slower queries — sequential scans must read through dead tuples, and index scans may point to dead rows. Third, wasted I/O — your operating system cache, your shared buffers, even your backups are storing useless dead data. In production, a heavily-updated table can easily become 5 to 10 times larger than its actual data.

- 1. Wasted Disk Space — table stores 35K dead rows for 5K live rows
- 2. Slower Sequential Scans — reads ALL pages including dead tuple pages
- 3. Slower Index Scans — index may point to dead tuples (wasted lookups)
- 4. Wasted shared_buffers — caching dead data instead of useful pages
- 5. Wasted I/O — OS reads dead pages from disk into memory for nothing
- 6. Larger Backups — pg_dump and pg_basebackup copy dead data too
- 7. Production risk: tables can grow 5-10x without maintenance

### VACUUM — What It Actually Does
Now for the solution — VACUUM. When you run VACUUM on a table, PostgreSQL scans the table, finds all dead tuples, and marks their space as reusable. It does NOT return the space to the operating system — the table file stays the same size on disk — but future inserts and updates can reuse those slots instead of making the file grow further. Think of it as shredding the old documents in your filing cabinet but keeping the drawer. The drawer is now empty and ready for new documents.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Scans Table** | Reads every page, identifies dead tuples that no transaction can see |
| **Marks Space Reusable** | Updates the Free Space Map (FSM) — future INSERTs can reuse these slots |
| **Updates Visibility Map** | Marks all-visible pages so index-only scans can skip heap lookups |
| **Freezes Old Tuples** | Prevents transaction ID wraparound (we will cover this later) |

**Notes:**
- VACUUM does NOT shrink the table file on disk
- VACUUM does NOT lock the table — reads and writes continue normally

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description — all the SQL scripts we are using are included. If you want to support this free course, there is a donation link in the description as well. Every bit helps keep this content free and available for everyone.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### FSM & VM — VACUUM's Internal Helpers
Let us see the Free Space Map and Visibility Map — two internal structures that VACUUM maintains. The Free Space Map tracks how much free space each page has, so PostgreSQL knows where to put new rows. The Visibility Map tracks which pages have only visible tuples, enabling index-only scans to skip the heap entirely. Both are critical for performance, and both are updated by VACUUM.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Free Space Map (FSM)** | Tracks free space per page — INSERT checks FSM to find a page with room |
| **Visibility Map (VM)** | One bit per page: is EVERY tuple on this page visible to ALL transactions? |
| **Index-Only Scans** | If VM says page is all-visible, skip heap lookup entirely — much faster |
| **VACUUM updates both** | After removing dead tuples, marks freed space in FSM and updates VM bits |

**Notes:**
- pg_freespace extension: SELECT * FROM pg_freespace('bloat_test');
- pg_visibility extension: SELECT * FROM pg_visibility('bloat_test');

### Beginner Trap: VACUUM Did Not Shrink My Table!
Here is a common beginner trap. You run VACUUM and expect the table to shrink on disk. It does not. You check the file size — it is the same. You think VACUUM did not work. It did work — it cleaned dead tuples and marked space as reusable — but VACUUM by design does not return disk space to the operating system. If you truly need to shrink the file on disk, you need VACUUM FULL, which we cover in the next class. But VACUUM FULL has a big tradeoff — it locks the entire table.

| What You Expected | What Actually Happened |
| :--- | :--- |
| VACUUM removes dead tuples | VACUUM DID remove dead tuples |
| Table file should get smaller | Space is marked REUSABLE inside the file |
| Disk space should be freed | New INSERTs fill empty slots (no file growth) |
| But: table size UNCHANGED! | Table file stays same size — by design |
| Did VACUUM even work?! | Use VACUUM FULL to actually shrink (but it LOCKS!) |


---

## 3. Hands-On Commands & psql Output

### Creating Dead Tuples — Demo Setup
**Explanation:** Let us see dead tuples in action. We will create a test table, insert some rows, then update and delete them to generate dead tuples. Watch how PostgreSQL tracks this in its statistics.

```sql
postgres=# -- Create a test table
postgres=# CREATE TABLE bloat_test (
    id SERIAL PRIMARY KEY,
    data TEXT,
    updated_at TIMESTAMPTZ DEFAULT now()
);
postgres=# CREATE TABLE
postgres=# -- Insert 10,000 rows
postgres=# INSERT INTO bloat_test (data)
postgres=# SELECT 'Original row ' || g
postgres-# FROM generate_series(1, 10000) AS g;
postgres=# INSERT 0 10000
postgres=# -- Check initial table size
postgres=# SELECT pg_size_pretty(pg_relation_size('bloat_test')) AS table_size;
 table_size
postgres=# -----------
 480 kB
```

### Generating Dead Tuples with UPDATE
**Explanation:** Now let us generate dead tuples. We will update every single row — this creates 10,000 new tuples and leaves 10,000 dead tuples behind. Then we check the statistics to see the damage.

```sql
postgres=# -- Update ALL rows (creates 10,000 dead tuples)
postgres=# UPDATE bloat_test SET data = 'Updated row ' || id, updated_at = now();
postgres=# UPDATE 10000
postgres=# -- Check table size AFTER update
postgres=# SELECT pg_size_pretty(pg_relation_size('bloat_test')) AS table_size;
 table_size
postgres=# -----------
 960 kB
postgres=# -- Table DOUBLED in size! Old versions still occupy space.
```

### Checking Dead Tuples in pg_stat_user_tables
**Explanation:** The table doubled from 480 kilobytes to 960 kilobytes — because the old versions are still physically there. Let us check pg_stat_user_tables to see exactly how many dead tuples we have.

```sql
postgres=# SELECT relname,
       n_live_tup,
       n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup, 0) * 100, 1)
postgres-# AS dead_pct
postgres-# FROM pg_stat_user_tables
postgres-# WHERE relname = 'bloat_test';
   relname   | n_live_tup | n_dead_tup | dead_pct
postgres=# -------------+------------+------------+----------
 bloat_test  |      10000 |      10000 |    100.0
postgres=# -- 10,000 dead tuples = 100% bloat ratio!
postgres=# -- Every live row has a dead twin sitting next to it
```

### Bloat Grows with Every UPDATE
**Explanation:** What happens if we keep updating without cleaning up? Let us update all rows two more times and see the damage grow.

```sql
postgres=# -- Update ALL rows again (two more rounds)
postgres=# UPDATE bloat_test SET data = 'Round 2: ' || id;
postgres=# UPDATE 10000
postgres=# UPDATE bloat_test SET data = 'Round 3: ' || id;
postgres=# UPDATE 10000
postgres=# -- Check the damage
postgres=# SELECT pg_size_pretty(pg_relation_size('bloat_test')) AS table_size;
 table_size
postgres=# -----------
 1960 kB
postgres=# SELECT n_live_tup, n_dead_tup,
       ROUND(n_dead_tup::numeric / NULLIF(n_live_tup, 0) * 100, 1)
postgres-# AS dead_pct
postgres-# FROM pg_stat_user_tables WHERE relname = 'bloat_test';
 n_live_tup | n_dead_tup | dead_pct
postgres=# ------------+------------+----------
      10000 |      30000 |    300.0
postgres=# -- 30,000 dead tuples! Table is 4x its needed size
```

### DELETE Also Creates Dead Tuples
**Explanation:** DELETE creates dead tuples too. Let us delete half the rows and check.

```sql
postgres=# -- Delete half the rows
postgres=# DELETE FROM bloat_test WHERE id <= 5000;
postgres=# DELETE 5000
postgres=# SELECT n_live_tup, n_dead_tup
postgres-# FROM pg_stat_user_tables WHERE relname = 'bloat_test';
 n_live_tup | n_dead_tup
postgres=# ------------+------------
       5000 |      35000
postgres=# -- 5,000 live rows but 35,000 dead tuples!
postgres=# -- The deleted rows are still physically on disk
postgres=# -- Sequential scans must read through ALL of them
```

### Running VACUUM — Dead Tuples Cleared
**Explanation:** Let us run VACUUM and see the results. Watch the dead tuple count drop to zero, but notice the table size stays the same.

```sql
postgres=# -- Run VACUUM with verbose output
postgres=# VACUUM (VERBOSE) bloat_test;
INFO:  vacuuming "public.bloat_test"
INFO:  finished vacuuming "public.bloat_test":
  index scans: 1
  pages: 0 removed, 245 remain, 245 scanned
  tuples: 35000 removed, 5000 remain, 0 are dead but not yet removable
  removable cutoff: 950
VACUUM
postgres=# -- Check dead tuples — should be zero
postgres=# SELECT n_live_tup, n_dead_tup
postgres-# FROM pg_stat_user_tables WHERE relname = 'bloat_test';
 n_live_tup | n_dead_tup
postgres=# ------------+------------
       5000 |          0
postgres=# -- But table size is UNCHANGED!
postgres=# SELECT pg_size_pretty(pg_relation_size('bloat_test')) AS table_size;
 table_size
postgres=# -----------
 1960 kB
```

### VACUUM Reclaims Space INSIDE the Table
**Explanation:** Notice that? VACUUM removed 35,000 dead tuples, but the table is still 1960 kilobytes. The space is marked as reusable within the table, but the file on disk did not shrink. This is by design — VACUUM runs without locking the table, so it cannot reorganize the file. If we insert new rows now, they will fill the empty slots instead of making the file bigger.

```sql
postgres=# -- Insert 5000 new rows — they fill the reclaimed space
postgres=# INSERT INTO bloat_test (data)
postgres=# SELECT 'New row ' || g
postgres-# FROM generate_series(1, 5000) AS g;
postgres=# INSERT 0 5000
postgres=# -- Table size stays the same — reused the empty slots!
postgres=# SELECT pg_size_pretty(pg_relation_size('bloat_test')) AS table_size;
 table_size
postgres=# -----------
 1960 kB
postgres=# -- Without VACUUM, this would have grown to ~2400 kB
postgres=# -- VACUUM prevented further growth by reusing dead tuple space
```

### VACUUM Syntax & Options
**Explanation:** Here are all the VACUUM options you should know. Plain VACUUM just cleans dead tuples. VACUUM VERBOSE shows details of what was cleaned. VACUUM with a table name targets just that table. VACUUM without a table name processes the entire database. You can also vacuum specific columns, which is useful for updating statistics on heavily-queried columns.

```sql
-- Basic VACUUM (entire database)
VACUUM;

-- VACUUM a specific table
VACUUM bloat_test;

-- VACUUM with verbose output (shows details)
VACUUM (VERBOSE) bloat_test;

-- VACUUM + ANALYZE (clean + update statistics)
VACUUM ANALYZE bloat_test;

-- VACUUM specific columns (updates stats for those columns)
VACUUM ANALYZE bloat_test (data, updated_at);

-- VACUUM with parallel workers (PG 13+)
VACUUM (PARALLEL 4) bloat_test;

-- VACUUM FREEZE (prevent transaction ID wraparound)
VACUUM (FREEZE) bloat_test;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: VACUUM Did Not Shrink My Table!
Here is a common beginner trap. You run VACUUM and expect the table to shrink on disk. It does not. You check the file size — it is the same. You think VACUUM did not work. It did work — it cleaned dead tuples and marked space as reusable — but VACUUM by design does not return disk space to the operating system. If you truly need to shrink the file on disk, you need VACUUM FULL, which we cover in the next class. But VACUUM FULL has a big tradeoff — it locks the entire table.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us wrap up with a quick summary card of everything we learned. Dead tuples are the natural byproduct of MVCC — every UPDATE and DELETE leaves behind invisible row versions. Bloat is the accumulated waste from these dead tuples. VACUUM cleans dead tuples and marks space as reusable, but does not shrink the table file. Always check pg_stat_user_tables to monitor dead tuple ratios. In the next class, we cover VACUUM FULL and AUTOVACUUM — the two sides of automated cleanup.

- **Dead Tuple: old row version no transaction can see (from UPDATE/DELETE)**
- **Bloat: wasted disk space from accumulated dead tuples**
- **VACUUM: scans table, marks dead tuple space as reusable**
- **VACUUM does NOT shrink the table file on disk**
- **VACUUM does NOT lock the table — safe to run during production**
- **VACUUM updates FSM (free space) and VM (visibility map)**
- **Monitor: pg_stat_user_tables → n_dead_tup, n_live_tup**
- **Next: VACUUM FULL (shrinks table, but LOCKS it) & AUTOVACUUM**


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
