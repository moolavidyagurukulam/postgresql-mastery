# Query Flow & MVCC — Parse, Plan, Execute & Tuple Visibility
**Series:** PostgreSQL Mastery | **Phase:** Phase 9: Architecture | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we follow a query from the moment you press Enter to the moment results come back. You will see the four stages — Parse, Rewrite, Plan, Execute — and then learn MVCC, Multi-Version Concurrency Control, which is how PostgreSQL lets multiple transactions read and write at the same time without locking each other out. Let us dive in.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand the storage architecture from the previous class — data files, pages, and WAL. You know that data lives in eight-kilobyte pages inside the data directory. Now we learn what happens BETWEEN your SQL arriving at the server and the results coming back. There are four stages every query goes through, and understanding them helps you read EXPLAIN output and write better queries.

- You know the storage architecture: pages, files, WAL
- Data lives in 8 KB pages inside base/<db_oid>/
- Previous class: WHERE data lives on disk
- This class: HOW a query processes that data
- Four stages: Parse → Rewrite → Plan → Execute
- Plus: MVCC — how concurrent transactions see data

### Query Processing Pipeline
When your SQL arrives at a backend process, it goes through four stages. Stage one is the Parser — it checks the SQL syntax and builds a parse tree. Stage two is the Rewriter — it applies view definitions and rules, expanding your query. Stage three is the Planner — also called the optimizer — it decides HOW to execute the query: which indexes to use, which join algorithm, what order to scan tables. Stage four is the Executor — it actually runs the plan and returns results.

```
[SQL Query]
[1. Parser
(syntax check → parse tree)]
[2. Rewriter
(expand views & rules)]
[3. Planner/Optimizer
(choose best execution plan)]
[4. Executor
(run plan, return rows)]
[Results
(to client)]
```

### MVCC — Multi-Version Concurrency Control
Now for the big concept — MVCC. Multi-Version Concurrency Control is PostgreSQL's approach to concurrent access. Instead of locking rows when someone reads them, PostgreSQL keeps MULTIPLE VERSIONS of each row. Each version has two hidden columns: xmin — the transaction ID that created this version, and xmax — the transaction ID that deleted or updated it. Zero means no one has deleted it yet. This is how readers never block writers and writers never block readers.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Core Idea** | Keep multiple versions of each row (tuple) |
| **xmin** | Transaction ID that CREATED this tuple version |
| **xmax** | Transaction ID that DELETED/UPDATED it (0 = alive) |
| **Benefit** | Readers never block writers, writers never block readers |
| **Cost** | Dead tuples accumulate → VACUUM cleans them up |

**Notes:**
- UPDATE = INSERT new version + mark old version deleted (xmax set)

### Support This Free Course!
Quick pause! If you are learning from this course, please support us. Hit the like button, share this video with someone learning PostgreSQL, and subscribe with the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping your career, consider supporting us — donation link is also in the description. Now let us continue!

- Like this video — it helps others find the course
- Share with someone learning PostgreSQL
- Subscribe + Bell icon — never miss a class
- Download today's class materials — link in description
- Support us: donation link in description
- Let us continue!

### Tuple Visibility Rules
Tuple visibility is how MVCC decides which version of a row you can see. When your transaction starts, it gets a snapshot — a list of which transactions are committed, which are in progress, and which have not started yet. A tuple is VISIBLE to you if: xmin is committed AND your snapshot can see it, AND xmax is either zero, or the deleting transaction aborted, or it committed but AFTER your snapshot. This is how two transactions can see different versions of the same row at the same time.

| Tuple IS Visible When | Tuple is NOT Visible When |
| :--- | :--- |
| xmin transaction committed | xmin still in progress (not yet committed) |
| xmin committed BEFORE your snapshot | xmin aborted (INSERT rolled back) |
| xmax is 0 (not deleted) | xmin committed AFTER your snapshot |
| OR xmax transaction aborted | xmax committed BEFORE your snapshot |
| OR xmax committed AFTER your snapshot | = row was deleted before you looked |

### Practice Exercises
Practice exercises: use EXPLAIN and EXPLAIN ANALYZE to see the query pipeline in action. Check xmin and xmax on your tables. Run an UPDATE and watch xmin change. Check dead tuples and run VACUUM. Monitor your transaction snapshots.

- 1. EXPLAIN SELECT * FROM employees; — see the plan
- 2. EXPLAIN (ANALYZE, BUFFERS) — see actual execution
- 3. SELECT xmin, xmax, * FROM employees; — see MVCC columns
- 4. UPDATE a row, then check xmin again — it changes!
- 5. Check dead tuples: pg_stat_user_tables n_dead_tup
- 6. VACUUM employees; then check n_dead_tup again
- 7. SELECT txid_current(); and txid_current_snapshot();


---

## 3. Hands-On Commands & psql Output

### Stage 1: Parser — Syntax Validation
**Explanation:** The Parser validates syntax. If you write SELCET instead of SELECT, the parser catches it — you get a syntax error. If the syntax is correct, it builds a parse tree — a structured representation of your query. The parser does NOT check if table or column names exist — that happens during analysis, right after parsing. This is why you get 'relation does not exist' as a different error from syntax errors.

```sql
-- Parser catches syntax errors
practice=# SELCET * FROM employees;
ERROR:  syntax error at or near "SELCET"
LINE 1: SELCET * FROM employees;
        ^

-- Analysis (after parser) catches unknown objects
practice=# SELECT * FROM nonexistent_table;
ERROR:  relation "nonexistent_table" does not exist
LINE 1: SELECT * FROM nonexistent_table;
                      ^

-- Parser OK, analysis catches bad column
practice=# SELECT fake_column FROM employees;
ERROR:  column "fake_column" does not exist
```

### Stage 3: Planner — Choosing the Best Path
**Explanation:** The Planner is the most interesting stage. It considers multiple execution strategies and picks the cheapest one. Should it do a sequential scan or use an index? Should it use a nested loop join, hash join, or merge join? It estimates costs using statistics from pg_statistic — row counts, value distributions, and correlation. EXPLAIN shows you the plan the planner chose. EXPLAIN ANALYZE actually runs the query and shows real timings versus estimates.

```sql
-- See the plan WITHOUT running the query
practice=# EXPLAIN SELECT * FROM employees WHERE department = 'Engineering';
                       QUERY PLAN
-----------------------------------------------------------
 Seq Scan on employees  (cost=0.00..1.11 rows=3 width=126)
   Filter: (department = 'Engineering'::text)

-- Run it AND show actual times + row counts
practice=# EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM employees WHERE department = 'Engineering';
 Seq Scan on employees  (cost=0.00..1.11 rows=3 width=126)
                        (actual time=0.015..0.018 rows=4 loops=1)
   Filter: (department = 'Engineering'::text)
   Rows Removed by Filter: 5
   Buffers: shared hit=1
 Planning Time: 0.085 ms
 Execution Time: 0.035 ms
```

### Seeing xmin and xmax
**Explanation:** You can actually see xmin and xmax. They are hidden system columns on every table. When you INSERT a row, xmin is set to your transaction ID and xmax is zero. When you UPDATE a row, PostgreSQL creates a NEW tuple with a new xmin, and sets xmax on the OLD tuple to the updating transaction's ID. The old tuple is now a dead tuple — it still exists on disk until VACUUM removes it.

```sql
-- xmin and xmax are hidden columns on every row
practice=# SELECT xmin, xmax, id, name FROM employees LIMIT 5;
  xmin  | xmax | id |  name
--------+------+----+--------
 100742 |    0 |  1 | Meera
 100742 |    0 |  2 | Ravi
 100742 |    0 |  3 | Sonia
 100742 |    0 |  4 | Priya
 100742 |    0 |  5 | Arjun

-- xmax = 0 means nobody has deleted/updated these rows
-- xmin = 100742 is the INSERT transaction's ID

-- Now update a row and check again
practice=# UPDATE employees SET salary = 130000 WHERE id = 1;
practice=# SELECT xmin, xmax, id, name, salary FROM employees WHERE id = 1;
  xmin  | xmax | id | name  | salary
--------+------+----+-------+---------
 100789 |    0 |  1 | Meera | 130000
-- New xmin! The UPDATE created a new tuple version
```

### Dead Tuples and VACUUM
**Explanation:** MVCC creates dead tuples. Every UPDATE leaves behind the old version of the row with xmax set. Every DELETE marks a tuple as dead. These dead tuples take up space but are invisible to new transactions. VACUUM is the process that reclaims this space. Without VACUUM, your tables would grow forever, full of dead rows. Autovacuum runs automatically, but you should monitor it to ensure it keeps up with your workload.

```sql
-- Check dead tuples per table
practice=# SELECT relname,
  n_live_tup, n_dead_tup,
  last_vacuum, last_autovacuum
FROM pg_stat_user_tables;
  relname   | n_live_tup | n_dead_tup | last_vacuum | last_autovacuum
-----------+------------+------------+-------------+----------------
 employees |          9 |          1 | NULL        | 2024-01-15 10:30

-- n_dead_tup = 1 because we updated Meera's salary
-- The old version (salary=120000) is dead

-- Manual VACUUM
practice=# VACUUM employees;
VACUUM
-- Dead tuples reclaimed, space available for reuse
```

### Transaction Snapshots
**Explanation:** You can see current transaction IDs and snapshots live. txid_current gives your transaction ID. txid_current_snapshot shows what your transaction can see — it has three parts: the lower bound, the upper bound, and a list of in-progress transaction IDs. Everything below the lower bound is visible; everything at or above the upper bound is invisible; and the listed IDs in between are in-progress, so also invisible.

```sql
-- Your current transaction ID
practice=# SELECT txid_current();
 txid_current
--------------
       100795

-- Your current snapshot
practice=# SELECT txid_current_snapshot();
 txid_current_snapshot
-----------------------
 100795:100795:

-- Format: xmin:xmax:xip_list
-- xmin  = lowest still-active txid (all below committed)
-- xmax  = first unassigned txid (nothing at/above visible)
-- xip   = in-progress txids between xmin and xmax
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us recap. Every query goes through four stages: Parser checks syntax, Rewriter expands views and rules, Planner picks the cheapest execution strategy, and Executor runs the plan. MVCC keeps multiple tuple versions using xmin and xmax. Readers never block writers. Dead tuples accumulate from UPDATE and DELETE — VACUUM cleans them. Transaction snapshots determine which tuple versions are visible to each transaction. In the next class, we cover WAL and Checkpoints — how PostgreSQL guarantees crash safety. See you there!

- **Parse → Rewrite → Plan → Execute: every query's journey**
- **EXPLAIN shows the plan; EXPLAIN ANALYZE shows actual execution**
- **MVCC: multiple tuple versions, not row locks**
- **xmin: creating transaction ID; xmax: deleting transaction ID**
- **UPDATE = new tuple (new xmin) + old tuple marked dead (xmax)**
- **Snapshots decide visibility: committed before your snapshot = visible**
- **Dead tuples need VACUUM to reclaim space**
- **Autovacuum does this automatically — monitor it!**


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


---

## 8. Practice Exercises & Verified Answer Key

### Exercise 1: EXPLAIN (ANALYZE, BUFFERS) Profiling
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM employees WHERE department = 'Engineering';
```
*Explanation:* `EXPLAIN` shows the cost estimator's hypothetical execution plan. Adding `ANALYZE` actually runs the query, reporting real wall-clock timing, row counts, and buffer hits.

### Exercise 2: Inspect Hidden MVCC Columns
```sql
SELECT ctid, xmin, xmax, id, name, department, salary
FROM employees;
```
*Explanation:* `ctid` indicates `(block_number, offset_in_block)`. `xmin` records the transaction ID that inserted the row. `xmax` records 0 for unexpired rows or the transaction ID that deleted/updated it.

### Exercise 3: Observe Row Versioning During UPDATE
```sql
UPDATE employees
SET salary = salary + 1000
WHERE id = 1
RETURNING ctid, xmin, xmax, name, salary;
```
*Explanation:* In PostgreSQL, `UPDATE` never overwrites existing bytes in place. It marks the old row version with `xmax = current_xid` and writes a new row version with `xmin = current_xid` at a new `ctid`.

### Exercise 4: Track Dead Tuple Accumulation
```sql
SELECT relname, n_live_tup, n_dead_tup, last_vacuum, last_autovacuum
FROM pg_stat_user_tables
WHERE relname = 'employees';

VACUUM employees;
```
*Explanation:* Obsolete row versions remain on disk as dead tuples until reclaimed by `VACUUM`.

### Exercise 5: Inspect Transaction IDs and Snapshot Horizons
```sql
SELECT pg_current_xact_id() AS current_xid,
       pg_current_snapshot() AS active_snapshot;
```
*Explanation:* Snapshots follow format `xmin:xmax:xip_list`. Any transaction ID lower than `xmin` is committed and visible; any transaction ID equal to or greater than `xmax` is invisible.
