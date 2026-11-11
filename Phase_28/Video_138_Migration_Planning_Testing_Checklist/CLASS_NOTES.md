# Migration Planning & Testing Checklist
**Series:** PostgreSQL Mastery | **Phase:** 28 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we build a complete migration planning and testing checklist. Whether you are migrating from Oracle, MySQL, SQL Server, or another PostgreSQL version — this checklist applies to every migration project.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before planning a migration, you should have completed the previous classes on specific migration tools — Ora2Pg for Oracle, pgLoader for MySQL and SQL Server. You should understand PostgreSQL administration, backup and restore, and have basic project management awareness.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Migration Tools** | Ora2Pg, pgLoader, pg_upgrade — covered in previous classes |
| **PostgreSQL Admin** | Users, permissions, configuration, backup/restore |
| **Source DB Knowledge** | Understanding of the source database schema and application |
| **Project Planning** | Basic awareness of timelines, stakeholders, risk management |

### Comparison
Most database migrations fail not because of technical problems, but because of poor planning. Common failures include: no rollback plan, incomplete data validation, missed stored procedure conversions, application downtime longer than expected, and performance regressions discovered only in production. A checklist prevents these failures by making every step explicit.

| Common Migration Failures | What Prevents Failures |
| :--- | :--- |
| No rollback plan → stuck midway | Written rollback procedure tested beforehand |
| Incomplete data validation | Automated row count + checksum comparison |
| Missed stored procedure conversion | Code audit covering ALL database objects |
| Downtime 10x longer than planned | Rehearsal migration with measured timing |
| Performance regression in production | Performance benchmarks before AND after |
| Character encoding data corruption | Encoding validation before data transfer |

### Phase 1: Assessment Checklist
The assessment phase determines the scope of work. Count every database object — tables, views, indexes, stored procedures, triggers, sequences, jobs. Measure total data size. Identify the source database version and all installed extensions or modules. Document application connection patterns. Estimate downtime tolerance — how long can the application be offline?

- Inventory all objects -- Tables, views, indexes, constraints, sequences, triggers, functions, procedures, packages, jobs, synonyms.
- Measure data volume -- Total size, largest tables, growth rate. Determines migration time and hardware needs.
- Document source version -- Exact version, installed extensions/modules, configuration. Affects conversion rules.
- Map application connections -- How many apps connect? Which ORMs? Connection pooling? Read replicas?
- Define downtime tolerance -- Zero downtime? Maintenance window? Weekend? This drives the migration strategy.
- Run migration assessment tool -- Ora2Pg SHOW_REPORT or manual complexity scoring. Get person-day estimate.

### Phase 2: Schema Conversion Checklist
Schema conversion is where most of the technical work happens. Convert data types, rewrite constraints, convert stored procedures and triggers. Keep a mapping document for every type conversion decision. Test that the converted schema accepts all valid data patterns from the source.

- Export source DDL -- Use migration tool (Ora2Pg, pgLoader) or native export. Get complete schema SQL.
- Data type mapping document -- Document every type conversion: NUMBER→integer, VARCHAR2→varchar, BIT→boolean, etc.
- Convert constraints -- Primary keys, foreign keys, unique, check constraints. Verify naming conventions.
- Convert indexes -- B-tree, unique, partial. Note: some index types have no direct equivalent (bitmap→GIN).
- Convert stored procedures -- PL/SQL→PL/pgSQL or T-SQL→PL/pgSQL. This is the most labor-intensive step.
- Convert triggers -- Trigger syntax differs. PG triggers need a separate function. Test each one.
- Convert views -- Usually minor syntax changes. Test each view returns correct results.
- Test schema on empty DB -- Load converted DDL into empty PG database. Fix all errors before data migration.

### Phase 3: Data Migration Checklist
Data migration must be complete and correct. Choose your migration method — pgLoader for direct streaming, COPY for CSV import, or logical replication for zero-downtime. Whatever method you choose, validate data integrity after every transfer. Compare row counts, run checksums on critical columns, and spot-check business-critical records.

- Choose migration method -- pgLoader (direct), BCP+COPY (CSV), logical replication (zero-downtime). Based on size and downtime tolerance.
- Disable triggers and FKs -- Disable during bulk load for speed. Re-enable and validate after load completes.
- Load in correct order -- Tables → sequences → data → indexes → constraints → views → functions.
- Validate row counts -- Compare every table: source count vs target count. Zero difference allowed.
- Validate checksums -- md5(column::text) on critical columns. Compare source and target checksums.
- Sync sequences -- Set every sequence to max(id)+1 from its table. Prevents duplicate key errors.
- VACUUM ANALYZE -- Rebuild optimizer statistics after bulk load. Critical for query performance.
- Validate encoding -- Check for garbled characters. SELECT with LIKE '%\x%' to find bad bytes.

### Phase 4: Application Conversion Checklist
The application must work with PostgreSQL. This means updating connection strings, fixing SQL syntax differences, updating ORM configurations, and testing every feature. Do not assume that because the ORM abstracts the database, everything works — ORMs generate different SQL for different backends, and edge cases break.

- Update connection strings -- Driver, host, port (5432), database name. Use connection pooling (PgBouncer).
- Update ORM configuration -- Change dialect/adapter to PostgreSQL. Regenerate migrations if needed.
- Fix SQL syntax -- TOP→LIMIT, ISNULL→COALESCE, NVL→COALESCE, backticks→double quotes.
- Fix case sensitivity -- String comparisons are case-sensitive in PG. Use ILIKE or citext where needed.
- Fix GROUP BY -- PG requires all non-aggregated columns in GROUP BY. Audit every query.
- Test every feature -- Full regression test suite. Test CRUD, reports, search, pagination, exports.
- Performance test -- Run application benchmarks. Compare response times with source database.
- Update monitoring -- pg_stat_statements, log_min_duration_statement. Different metrics than source DB.

### Phase 5: Cutover Checklist
Cutover is the most critical phase — this is when you switch production traffic. Before the actual cutover, do at least two rehearsal runs to measure timing and find problems. On cutover day, follow the script exactly. Have a rollback plan ready. Monitor everything for 24 hours after the switch.

- Rehearsal migration (2x) -- Run the entire process end-to-end on staging. Measure total time. Fix issues.
- Communicate maintenance window -- Notify all stakeholders: when, how long, what will be unavailable.
- Final backup of source -- Full backup of source database immediately before cutover. Non-negotiable.
- Stop writes to source -- Set source to read-only or stop application. Zero new data during transfer.
- Final data sync -- Sync any data created since last migration. Verify lag = 0.
- Switch connection strings -- Point application to PostgreSQL. Rolling restart if needed.
- Validate production -- Run application smoke tests. Check critical flows. Monitor error rates.
- Monitor 24 hours -- Watch for slow queries, errors, connection issues. Keep source available for rollback.

### Comparison
If this migration planning guide is helping you, please support the course. Your donation keeps this course free for the community. Links for PayPal and UPI are in the description. Class materials are available on GitHub.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All commands from this video |
| Every donation helps! | Practice exercises included |

### Rollback Plan
Every migration needs a rollback plan. The simplest rollback is: keep the source database running for 24 to 48 hours after cutover. If problems arise, switch connection strings back to the source. For zero-downtime migrations using logical replication, you can set up reverse replication from PostgreSQL back to the source so data written to PostgreSQL flows back.

- Keep source running -- Do NOT decommission source for 24-48 hours after cutover. It is your safety net.
- Rollback trigger criteria -- Define beforehand: error rate > X%, response time > Y ms, data corruption detected.
- Rollback procedure -- 1. Stop app → 2. Switch connection string to source → 3. Restart app → 4. Verify.
- Data written post-cutover -- Any data written to PG after cutover is lost on rollback. Accept this or set up reverse replication.
- Reverse replication (optional) -- Set up PG→source replication. Expensive to set up but zero data loss on rollback.
- Test rollback in rehearsal -- Actually test the rollback procedure during rehearsal. Do not assume it works.

### Migration Timeline Template
Here is a realistic timeline template. Assessment takes one to two weeks. Schema conversion takes two to four weeks depending on stored procedure complexity. Data migration development and testing takes one to two weeks. Application conversion runs parallel with schema work — two to six weeks. Rehearsals take one week. Cutover itself takes hours to a day. Total: six to fourteen weeks for a medium-complexity migration.

| Term | Meaning / Explanation |
| :--- | :--- |
| **1. Assessment** | Duration: 1-2 weeks | Key Deliverable: Inventory + complexity report |
| **2. Schema Conversion** | Duration: 2-4 weeks | Key Deliverable: Converted DDL scripts (all passing) |
| **3. Data Migration Dev** | Duration: 1-2 weeks | Key Deliverable: Migration scripts + validation |
| **4. App Conversion** | Duration: 2-6 weeks (parallel) | Key Deliverable: All queries working on PG |
| **5. Integration Testing** | Duration: 1-2 weeks | Key Deliverable: Full regression pass |
| **6. Rehearsal (2x)** | Duration: 1 week | Key Deliverable: Measured timing + issues fixed |
| **7. Cutover** | Duration: 4-24 hours | Key Deliverable: Production on PostgreSQL |
| **8. Post-Cutover Monitor** | Duration: 1-2 weeks | Key Deliverable: Stable performance confirmed |
| **TOTAL** | Duration: 6-14 weeks | Key Deliverable: Complete migration |

### Migration Strategy Decision Framework
Choosing the right migration strategy depends on three factors: data volume, downtime tolerance, and code complexity. For small databases with a maintenance window, a simple dump and restore is fine. For large databases with no downtime tolerance, you need logical replication. For complex Oracle PL/SQL code, budget significant time for manual conversion.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Small DB, downtime OK** | Strategy: Dump + convert + restore | Tool: pg_dump / Ora2Pg |
| **Medium DB, short window** | Strategy: pgLoader direct streaming | Tool: pgLoader |
| **Large DB, no downtime** | Strategy: Logical replication cutover | Tool: Built-in logical rep |
| **Oracle with packages** | Strategy: Ora2Pg + manual PL/SQL work | Tool: Ora2Pg |
| **MySQL, simple schema** | Strategy: One-command pgLoader | Tool: pgLoader |
| **SQL Server, many procs** | Strategy: pgLoader + manual T-SQL conv | Tool: pgLoader + manual |
| **PG major version upgrade** | Strategy: pg_upgrade (link mode) | Tool: pg_upgrade |
| **PG upgrade, no downtime** | Strategy: Logical replication | Tool: Built-in logical rep |

### Beginner Traps — Migration Planning
Watch out for these planning mistakes. First, never skip the rehearsal — the first time you run the migration should never be on production. Second, do not estimate migration time from small test data — a table with 100 rows migrates in milliseconds, the same table with 100 million rows takes hours. Third, do not forget sequences — the most common post-migration bug is duplicate key errors because sequences were not synced. Fourth, always keep the source running for rollback.

- Never skip rehearsal -- First migration run on production = guaranteed surprises. Always rehearse on staging first.
- Test with real data volume -- 100 rows: 0.1s. 100M rows: 3 hours. Time estimates from small data are worthless.
- Sync ALL sequences -- Most common post-migration bug: duplicate key errors. Run setval for EVERY sequence.
- Keep source for rollback -- Do NOT shut down source database for at least 24 hours after cutover. It is insurance.
- Test application, not just data -- Data migrated correctly ≠ application works correctly. Test every feature end-to-end.

### Complete Migration Checklist
Here is the complete checklist in one place. Print this out and check off each item as you complete it. Assessment: inventory, sizing, complexity score. Schema: type mapping, DDL conversion, procedure conversion. Data: migration, validation, sequence sync. Application: connection strings, SQL fixes, testing. Cutover: rehearsal, backup, switch, monitor, rollback plan.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Assessment** | Item: Object inventory complete | Status: [ ] |
| **Assessment** | Item: Data volume measured | Status: [ ] |
| **Assessment** | Item: Complexity score / estimate | Status: [ ] |
| **Schema** | Item: Type mapping documented | Status: [ ] |
| **Schema** | Item: DDL loads without errors | Status: [ ] |
| **Schema** | Item: All procedures converted | Status: [ ] |
| **Data** | Item: Row counts match (all tables) | Status: [ ] |
| **Data** | Item: Checksums match (critical tables) | Status: [ ] |
| **Data** | Item: Sequences synced | Status: [ ] |
| **App** | Item: Connection strings updated | Status: [ ] |
| **App** | Item: All queries tested on PG | Status: [ ] |
| **App** | Item: Performance benchmarks pass | Status: [ ] |
| **Cutover** | Item: Rehearsal completed (2x) | Status: [ ] |
| **Cutover** | Item: Rollback plan tested | Status: [ ] |
| **Cutover** | Item: Source backup taken | Status: [ ] |
| **Cutover** | Item: 24-hour monitoring active | Status: [ ] |

### Practice Exercises
Here are your practice exercises. First, create a migration assessment for a test database — count all objects, measure sizes, estimate complexity. Second, plan a migration timeline using the template from this class. Third, perform a full rehearsal migration of a test database — schema, data, validation, application testing. Fourth, practice the rollback procedure — switch to PostgreSQL, then switch back to the source. Measure total rollback time.

- Exercise 1 -- Create a migration assessment for a test database. Count all objects. Measure total size. Score complexity.
- Exercise 2 -- Build a migration timeline using the 8-phase template. Assign dates and owners to each phase.
- Exercise 3 -- Full rehearsal: migrate a test DB end-to-end. Schema + data + validation + app test. Time everything.
- Exercise 4 -- Practice rollback: switch to PG, insert test data, rollback to source. Measure total rollback time.
- Exercise 5 -- Set up post-cutover monitoring (pg_stat_statements + slow query log). Run queries under load. Review reports.


---

## 3. Hands-On Commands & psql Output

### Assessment Queries (PostgreSQL Source Example)
**Explanation:** Run these queries on your source database to build the inventory. Count tables, views, procedures, and functions. Measure total data size. Identify the largest tables that will take the most time to migrate. These numbers go into your project plan.

```sql
-- Count objects by type:
SELECT
  (SELECT count(*) FROM pg_class WHERE relkind='r'
   AND relnamespace = 'public'::regnamespace) AS tables,
  (SELECT count(*) FROM pg_class WHERE relkind='v'
   AND relnamespace = 'public'::regnamespace) AS views,
  (SELECT count(*) FROM pg_class WHERE relkind='i'
   AND relnamespace = 'public'::regnamespace) AS indexes,
  (SELECT count(*) FROM pg_class WHERE relkind='S'
   AND relnamespace = 'public'::regnamespace) AS sequences,
  (SELECT count(*) FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace) AS functions;

-- Total database size:
SELECT pg_size_pretty(pg_database_size(current_database()));

-- Top 10 largest tables:
SELECT relname,
  pg_size_pretty(pg_total_relation_size(oid)) AS total_size,
  n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 10;
```

### Data Validation Queries
**Explanation:** Here are the actual queries for data validation. Run these on both the source and target databases. Compare row counts per table. For critical tables, compute a hash of key columns and compare. These queries catch missing rows, truncated data, and encoding problems.

```sql
-- Row count per table (run on BOTH databases):
SELECT relname AS table_name, n_live_tup AS row_count
FROM pg_stat_user_tables
ORDER BY relname;

-- Exact count (pg_stat can lag behind):
SELECT 'employees' AS tbl, count(*) FROM employees
UNION ALL
SELECT 'orders', count(*) FROM orders
UNION ALL
SELECT 'products', count(*) FROM products;

-- Checksum on critical columns:
SELECT md5(string_agg(
  emp_id::text || name || salary::text,
  ',' ORDER BY emp_id
)) AS employees_checksum
FROM employees;

-- Check for NULL where NOT NULL expected:
SELECT count(*) AS null_names
FROM employees WHERE name IS NULL;

-- Sequence sync verification:
SELECT sequencename, last_value
FROM pg_sequences
WHERE schemaname = 'public';
```

### Performance Testing
**Explanation:** Performance must be tested before cutover — not after. Run your application's top 20 most frequent queries on both the source and PostgreSQL. Compare execution plans and timing. Common performance issues: missing indexes that existed in the source, different optimizer behavior requiring ANALYZE, and queries that need rewriting because PostgreSQL's planner makes different choices.

```sql
postgres=#-- Enable query timing
postgres=#\timing on
postgres=#-- Run top application query
postgres=#EXPLAIN (ANALYZE, BUFFERS) SELECT e.name, d.dept_name
FROM employees e JOIN departments d ON e.dept_id = d.dept_id
WHERE e.hire_date > '2024-01-01';

 Hash Join  (cost=1.52..412.87 rows=2847 width=64)
   (actual time=0.045..3.217 rows=2841 loops=1)
   Buffers: shared hit=187
 Planning Time: 0.125 ms
 Execution Time: 3.842 ms
postgres=#-- Compare with source DB timing
postgres=#-- Source: 4.2ms | PG: 3.8ms → OK
```

### Post-Cutover Monitoring Queries
**Explanation:** Here are the queries to run after cutover. Check for slow queries using pg_stat_statements. Monitor active connections. Watch for lock contention. Check disk usage growth. These queries should run every hour for the first 24 hours.

```sql
-- Top 10 slowest queries:
SELECT calls, mean_exec_time::numeric(10,2) AS avg_ms,
  total_exec_time::numeric(10,2) AS total_ms,
  left(query, 80) AS query
FROM pg_stat_statements
ORDER BY mean_exec_time DESC LIMIT 10;

-- Active connections:
SELECT state, count(*)
FROM pg_stat_activity
WHERE backend_type = 'client backend'
GROUP BY state;

-- Lock contention:
SELECT blocked.pid, blocked_activity.query AS blocked_query,
  blocking.pid AS blocking_pid
FROM pg_locks blocked
JOIN pg_stat_activity blocked_activity
  ON blocked.pid = blocked_activity.pid
JOIN pg_locks blocking
  ON blocked.locktype = blocking.locktype
  AND blocked.pid != blocking.pid
WHERE NOT blocked.granted;

-- Database size growth:
SELECT pg_size_pretty(pg_database_size(current_database()));
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — Post-Cutover Monitoring Settings
After cutover, monitor intensively for the first 24 to 48 hours. Enable pg_stat_statements to track query performance. Set log_min_duration_statement to catch slow queries. Watch connection counts, replication lag if using replicas, disk usage growth, and error rates. Set up alerts for any anomaly. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `shared_preload_libraries` | `'pg_stat_statements'` | **`[RESTART]`** (Postmaster Restart) | Track query stats (Default: '') |
| `pg_stat_statements.track` | `all` | `[SETTING]` | Track all statements |
| `log_min_duration_statement` | `500` | `[RELOAD]` (Live Reload `SIGHUP`) | Log queries > 500ms (Default: -1) |
| `log_checkpoints` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Log checkpoint activity (Default: off) |
| `log_connections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Log new connections (Default: off) |
| `log_disconnections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Log disconnections (Default: off) |
| `log_lock_waits` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Log lock waits > deadlock_timeout (Default: off) |
| `log_temp_files` | `0` | `[RELOAD]` (Live Reload `SIGHUP`) | Log all temp file creation (Default: -1) |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Migration Planning
Watch out for these planning mistakes. First, never skip the rehearsal — the first time you run the migration should never be on production. Second, do not estimate migration time from small test data — a table with 100 rows migrates in milliseconds, the same table with 100 million rows takes hours. Third, do not forget sequences — the most common post-migration bug is duplicate key errors because sequences were not synced. Fourth, always keep the source running for rollback.

- Never skip rehearsal -- First migration run on production = guaranteed surprises. Always rehearse on staging first.
- Test with real data volume -- 100 rows: 0.1s. 100M rows: 3 hours. Time estimates from small data are worthless.
- Sync ALL sequences -- Most common post-migration bug: duplicate key errors. Run setval for EVERY sequence.
- Keep source for rollback -- Do NOT shut down source database for at least 24 hours after cutover. It is insurance.
- Test application, not just data -- Data migrated correctly ≠ application works correctly. Test every feature end-to-end.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. Every migration follows five phases: assessment, schema conversion, data migration, application conversion, and cutover. Assessment first — count objects, measure volume, score complexity. Convert schema before data. Validate with row counts and checksums. Never skip rehearsals — do at least two. Keep the source running for rollback. Monitor intensively for 24 to 48 hours post-cutover. The migration is complete only when production has been stable for at least one full business cycle.

- **Five phases: Assessment → Schema → Data → App → Cutover**
- **Assessment first: inventory, volume, complexity score**
- **Schema conversion before data migration**
- **Validate: row counts + checksums + application tests**
- **Always rehearse (2x minimum) on staging before production**
- **Rollback plan is mandatory — keep source running 24-48 hours**
- **Monitor: pg_stat_statements + slow query log post-cutover**
- **Complete when stable for one full business cycle**


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
