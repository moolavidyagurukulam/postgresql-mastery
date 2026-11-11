# PostgreSQL DBA Daily Tasks & Top 50 Interview Questions
**Series:** PostgreSQL Mastery | **Phase:** 33 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. This is the final phase — Interview and Career preparation. In this class, we cover what a PostgreSQL DBA actually does every day. Then we go through the top 50 interview questions with clear, concise answers. Whether you are preparing for a DBA interview or transitioning into a database role, this class gives you the foundation.


---

## 2. Core Technical Concepts & Mechanisms

### DBA Morning Checklist
A PostgreSQL DBA's day starts with a morning health check. Check that all PostgreSQL instances are running. Check replication lag on standbys — it should be under a few seconds. Check disk space — databases grow every day. Review overnight backup status — did pgBackRest or pg_dump complete successfully? Check the PostgreSQL log for errors or warnings. This takes 15 to 30 minutes and catches problems before users report them.

- 1. Instance health — pg_isready on all servers. Check systemctl status postgresql. All nodes running?
- 2. Replication lag — pg_stat_replication on primary. Lag < 5 seconds. Alert if standby disconnected.
- 3. Disk space — df -h on data directories. pg_database_size(). Alert at 80% full. Plan capacity.
- 4. Backup status — pgBackRest info / check pg_dump logs. Last backup < 24 hours. Test restore monthly.
- 5. Log review — grep ERROR /var/log/postgresql/. Check for FATAL, PANIC, deadlock, checksum failures.
- 6. Connection count — pg_stat_activity count vs max_connections. Alert at 80%. Check idle-in-transaction.

### Comparison
Beyond the morning check, a DBA handles ongoing tasks throughout the day. Performance tuning — reviewing slow queries from pg_stat_statements. Security — managing roles, reviewing access. Schema changes — reviewing developer ALTER TABLE requests. Capacity planning — tracking growth trends. Incident response — when the database goes down at 3 AM. And documentation — keeping runbooks current. A DBA is part firefighter, part planner, part guardian.

| Daily / Weekly Tasks | Monthly / Quarterly |
| :--- | :--- |
| Review slow query log | Test backup restore (full) |
| Check autovacuum health | Test failover procedure |
| Monitor table bloat | Review role permissions |
| Review new index requests | Capacity planning review |
| Verify backup integrity | PostgreSQL minor version update |
| Check connection pool health | Update runbooks & documentation |

### Top 50 Questions — Fundamentals (1-5)
Let us start the top 50 questions. Question 1: What is PostgreSQL? An open-source object-relational database management system known for reliability, extensibility, and SQL compliance. Question 2: What is MVCC? Multi-Version Concurrency Control — readers never block writers. Each transaction sees a snapshot. Question 3: What is the difference between CHAR, VARCHAR, and TEXT? CHAR is fixed-length padded, VARCHAR has a limit, TEXT is unlimited. In PostgreSQL, all three perform the same — use VARCHAR or TEXT.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q1: What is PostgreSQL?** | Open-source ORDBMS. ACID-compliant. Extensible. Supports JSON, full-text, GIS. |
| **Q2: What is MVCC?** | Multi-Version Concurrency Control. Readers don't block writers. Each tx sees a snapshot. |
| **Q3: CHAR vs VARCHAR vs TEXT?** | CHAR(n): fixed-length. VARCHAR(n): max length. TEXT: unlimited. All perform the same in PG. |
| **Q4: What are ACID properties?** | Atomicity, Consistency, Isolation, Durability. Guarantees reliable transactions. |
| **Q5: Primary Key vs Unique?** | PK = NOT NULL + UNIQUE + only one per table. Unique allows NULL, multiple per table. |

### Top 50 Questions — Fundamentals (6-10)
Question 6: What is a foreign key? A column that references the primary key of another table, enforcing referential integrity. Question 7: What is the difference between DELETE, TRUNCATE, and DROP? DELETE removes rows with logging and rollback. TRUNCATE removes all rows instantly without row-level logging. DROP destroys the table entirely. Question 8: What are indexes and why are they important? Indexes speed up read queries by creating sorted lookup structures, but slow down writes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q6: What is a Foreign Key?** | References PK of another table. Enforces referential integrity. Prevents orphan rows. |
| **Q7: DELETE vs TRUNCATE vs DROP?** | DELETE: row-by-row, rollback OK. TRUNCATE: instant, minimal logging. DROP: destroys table. |
| **Q8: What are indexes?** | Sorted data structures for fast lookups. Speed reads, slow writes. B-tree is default. |
| **Q9: What is a transaction?** | A unit of work: BEGIN → SQL → COMMIT/ROLLBACK. All-or-nothing. Supports savepoints. |
| **Q10: What is a schema?** | A namespace within a database. Organizes tables. Default is 'public'. Search path controls. |

### Top 50 — Performance (11-15)
Question 11: How do you find slow queries? Use pg_stat_statements extension and log_min_duration_statement. Question 12: What is EXPLAIN ANALYZE? Shows the query execution plan with actual timing. Look for Seq Scan on large tables, high row estimates, and sort operations. Question 13: What are the main index types? B-tree for equality and range, GIN for full-text and arrays, GiST for geometric and range, BRIN for large sorted tables, Hash for exact equality. Question 14: What is a partial index? An index with a WHERE clause — indexes only matching rows.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q11: Finding slow queries?** | pg_stat_statements (top queries by time). log_min_duration_statement (log queries > N ms). |
| **Q12: EXPLAIN ANALYZE?** | Shows execution plan with actual times. Look for Seq Scan, high Rows Removed, disk reads. |
| **Q13: Index types?** | B-tree (default), GIN (full-text/arrays), GiST (geometry), BRIN (sorted data), Hash (=). |
| **Q14: Partial index?** | Index with WHERE clause. Smaller, faster. Example: WHERE active = true. Indexes only matching rows. |
| **Q15: Covering index?** | INCLUDE clause adds columns to index leaf. Index-only scan: no heap lookup needed. |

### Top 50 — Performance (16-20)
Question 16: What is connection pooling and why is it needed? PostgreSQL forks a new process per connection. 500 connections means 500 processes. PgBouncer pools connections — 1000 app connections share 25 database connections. Question 17: What is shared_buffers? PostgreSQL's in-memory cache for data pages. Set to 25 percent of RAM. Question 18: What is work_mem? Memory for sort and hash operations per query. Default 4 megabytes. Increase for complex queries.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q16: Connection pooling?** | PgBouncer shares DB connections. 1000 app conns → 25 DB conns. Transaction mode is best. |
| **Q17: shared_buffers?** | PG's data page cache. Set to 25% of RAM. Stores frequently accessed table and index pages. |
| **Q18: work_mem?** | Memory per sort/hash operation per query. Default 4MB. Higher = fewer disk sorts. |
| **Q19: effective_cache_size?** | Hint to planner about OS cache size. Set to 50-75% of RAM. Affects plan choice, not allocation. |
| **Q20: VACUUM and why needed?** | Reclaims dead rows from MVCC. Autovacuum runs automatically. Prevents bloat and wraparound. |

### Top 50 — Replication & HA (21-25)
Question 21: What is streaming replication? Primary sends WAL records to standby in real-time. Standby replays them. Near-zero lag. Question 22: Synchronous vs asynchronous replication? Synchronous waits for standby confirmation before commit — zero data loss but slower. Asynchronous commits immediately — faster but may lose a few transactions on failover. Question 23: What is a replication slot? Guarantees the primary keeps WAL until the standby confirms receipt. Prevents standby falling too far behind.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q21: Streaming replication?** | Primary streams WAL to standby in real-time. Standby replays. Hot standby allows reads. |
| **Q22: Sync vs async replication?** | Sync: waits for standby ACK. Zero data loss. Slower. Async: faster, may lose recent txns. |
| **Q23: Replication slot?** | Primary retains WAL until standby confirms. Prevents 'requested WAL already removed' error. |
| **Q24: Logical replication?** | Replicates by table, not entire cluster. Selective. Cross-version. Uses PUBLICATION/SUBSCRIPTION. |
| **Q25: What is Patroni?** | HA framework. Auto failover, auto promotion. Uses etcd/Consul for consensus. < 30s failover. |

### Comparison
If this interview preparation is helping you land your dream DBA role, please support the course. The complete question-and-answer list is available as a downloadable PDF and SQL file on GitHub.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: All 50 Q&A in .sql |
| UPI: Link in description | DBA monitoring queries |
| Every donation helps! | Interview cheat sheet |

### Top 50 — Backup & Recovery (26-30)
Question 26: What is Point-in-Time Recovery? Restore a base backup then replay WAL to any specific timestamp. Useful for recovering from accidental data deletion. Question 27: What is pg_basebackup? Creates a physical backup of the entire PostgreSQL cluster. Used to create standbys and base backups for PITR. Question 28: pgBackRest vs pg_dump? pgBackRest is for physical backups — incremental, parallel, compressed. pg_dump is logical — portable, selective, but slower for large databases.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q26: Point-in-Time Recovery?** | Restore base backup → replay WAL to exact timestamp. Recover from accidental DELETE/DROP. |
| **Q27: pg_basebackup?** | Physical backup of entire cluster. Creates standby (-R flag). Base for PITR. Streaming. |
| **Q28: pgBackRest vs pg_dump?** | pgBackRest: physical, incremental, fast. pg_dump: logical, portable, selective. Use both. |
| **Q29: WAL archiving?** | Copies completed WAL files to archive. Required for PITR. archive_mode=on, archive_command. |
| **Q30: Backup testing?** | Restore monthly to test server. Verify row counts. Time the restore. A backup never tested = no backup. |

### Top 50 — Security (31-35)
Question 31: What is pg_hba.conf? The client authentication file. Controls who can connect from where using which method. Processed top to bottom, first match wins. Question 32: What authentication methods does PostgreSQL support? scram-sha-256 is the modern default. Also supports md5, certificate, LDAP, GSSAPI, RADIUS, and trust. Question 33: What is Row-Level Security? Policies that filter rows per user. Each user sees only their allowed rows. Used for multi-tenancy.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q31: pg_hba.conf?** | Client auth config. TYPE DATABASE USER ADDRESS METHOD. First match wins. Reload to apply. |
| **Q32: Auth methods?** | scram-sha-256 (best), md5 (legacy), cert (SSL), LDAP, trust (no password — dev only). |
| **Q33: Row-Level Security?** | Per-row access control. ENABLE RLS + CREATE POLICY. Users see only matching rows. |
| **Q34: SSL/TLS encryption?** | ssl = on in postgresql.conf. Encrypts client-server traffic. Use ssl_cert_file, ssl_key_file. |
| **Q35: GRANT vs REVOKE?** | GRANT gives privileges. REVOKE removes them. Principle of least privilege. Audit regularly. |

### Top 50 — Advanced (36-40)
Question 36: What are CTEs? Common Table Expressions — WITH clauses that make complex queries readable. Recursive CTEs for tree structures. Question 37: What are window functions? Functions that calculate across rows related to the current row. ROW_NUMBER, RANK, LAG, LEAD, SUM OVER. Crucial for analytics. Question 38: What is table partitioning? Splitting a large table into smaller pieces. Range partitioning by date is most common. Query pruning skips irrelevant partitions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q36: CTEs (WITH clause)?** | Named subqueries for readability. Recursive CTEs for trees/hierarchies. Materialized in PG 16. |
| **Q37: Window functions?** | ROW_NUMBER, RANK, LAG, LEAD, SUM OVER. Calculate across related rows. Essential for analytics. |
| **Q38: Table partitioning?** | Split large table: range (by date), list (by category), hash (by ID). Prunes irrelevant parts. |
| **Q39: JSONB in PostgreSQL?** | Binary JSON. Indexed with GIN. Operators: ->, ->>, @>, ?. Flexible schema within relational. |
| **Q40: Full-text search?** | tsvector + tsquery. GIN index. Stemming, ranking, phrase search. Built-in, no external engine. |

### Top 50 — Operations (41-45)
Question 41: What is autovacuum? Automatic background process that reclaims dead rows and updates statistics. Essential for MVCC health. Never disable it. Question 42: What is transaction ID wraparound? PostgreSQL uses 32-bit transaction IDs. After 2 billion transactions, IDs wrap. Autovacuum freezes old rows to prevent this. If wraparound approaches, PostgreSQL shuts down to protect data. Question 43: How do you handle a PostgreSQL upgrade? Minor versions — just install and restart. Major versions — pg_upgrade with link mode for speed, or logical replication for zero-downtime.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q41: Autovacuum?** | Background daemon. Reclaims dead rows. Updates planner statistics. Never disable. Tune per table. |
| **Q42: Transaction wraparound?** | 32-bit txid wraps at 2 billion. Autovacuum freezes old rows. PG shuts down if too close. Monitor. |
| **Q43: Major version upgrade?** | pg_upgrade (--link for speed). Or logical replication for zero downtime. Test on staging first. |
| **Q44: pg_stat_statements?** | Extension tracking query stats: calls, total time, mean time, rows. Top-N slowest queries. |
| **Q45: Tablespaces?** | Store data on different disks. Fast SSD for hot tables. Archive storage for old data. |

### Top 50 — Final (46-50)
Question 46: What is the difference between a function and a procedure? Functions return values and can be used in queries. Procedures support transaction control — COMMIT and ROLLBACK inside. Question 47: What are triggers? Functions that execute automatically on INSERT, UPDATE, or DELETE. Before or after. Row-level or statement-level. Question 48: What is pg_repack? An extension that rebuilds tables online without locking. Alternative to VACUUM FULL for production. Question 49: What is the PostgreSQL write-ahead log? WAL ensures durability — all changes written to WAL before data files. Enables PITR and replication. Question 50: Why choose PostgreSQL over MySQL? Richer SQL, MVCC without lock issues, better JSON, extensions, full-text, GIS, and stronger ACID compliance.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Q46: Function vs Procedure?** | Function: returns value, used in queries. Procedure: transaction control (COMMIT/ROLLBACK inside). |
| **Q47: Triggers?** | Auto-fire on INSERT/UPDATE/DELETE. BEFORE/AFTER. Row/statement level. Audit, validation, sync. |
| **Q48: pg_repack?** | Online table rebuild. No locks. Shrinks bloated tables. Alternative to VACUUM FULL for production. |
| **Q49: Write-Ahead Log (WAL)?** | All changes to WAL first, then data. Crash recovery. Enables replication and PITR. |
| **Q50: PostgreSQL vs MySQL?** | Richer SQL, true MVCC, JSONB, extensions, full-text, GIS, better ACID. Enterprise-grade. |

### Interview Tips
Tips for PostgreSQL interviews. Always explain with examples — do not just define terms. Show you know the commands — say CREATE INDEX CONCURRENTLY, not just index. Mention trade-offs — every choice has pros and cons. Relate to production experience — even lab experience counts. Be honest about what you do not know — say you would check the documentation. And ask questions back — a DBA who asks clarifying questions before acting is exactly what companies want.

- Show commands, not just concepts — Say 'CREATE INDEX CONCURRENTLY' not just 'add an index'. Shows hands-on knowledge.
- Always mention trade-offs — Every design has pros/cons. Sync replication: safe but slower. Show you understand both sides.
- Relate to production scenarios — Tell stories: 'When I saw replication lag, I checked pg_stat_replication first.' Even lab stories.
- Be honest about unknowns — 'I would check the documentation' is better than guessing. Shows professional judgment.
- Ask clarifying questions — Before answering: 'What version?' 'How large is the table?' Shows DBA thinking.


---

## 3. Hands-On Commands & psql Output

### DBA Essential Monitoring Queries
**Explanation:** Every DBA should have these queries ready. Database size trend — track weekly growth. Table bloat check — dead tuple percentage. Unused indexes wasting space. Long-running queries that need investigation. Replication lag for HA monitoring. And connection state distribution. Save these as a script and run them daily. They tell you the health story of your database in 60 seconds.

```sql
-- Database sizes
SELECT datname,
  pg_size_pretty(pg_database_size(datname))
FROM pg_database ORDER BY
  pg_database_size(datname) DESC;

-- Table bloat (dead tuples)
SELECT relname, n_live_tup, n_dead_tup,
  round(100.0 * n_dead_tup /
    nullif(n_live_tup + n_dead_tup, 0), 1)
    AS dead_pct
FROM pg_stat_user_tables
WHERE n_dead_tup > 10000
ORDER BY n_dead_tup DESC LIMIT 10;

-- Unused indexes (wasting space)
SELECT indexrelname, idx_scan,
  pg_size_pretty(pg_relation_size(indexrelid))
FROM pg_stat_user_indexes
WHERE idx_scan = 0 ORDER BY
  pg_relation_size(indexrelid) DESC;

-- Long-running queries (> 1 min)
SELECT pid, now() - query_start AS duration,
  state, left(query, 60) AS query
FROM pg_stat_activity
WHERE state = 'active'
  AND now() - query_start > interval '1 min'
ORDER BY duration DESC;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Summary. A PostgreSQL DBA's day: morning health checks, performance monitoring, backup verification, security reviews, and capacity planning. The top 50 questions cover fundamentals, performance tuning, replication, backup and recovery, security, and advanced features. For interviews: show commands, explain trade-offs, relate to real scenarios, and be honest about what you need to look up. Download the complete question list from GitHub.

- **DBA morning: instance health, replication, disk, backups, logs, connections**
- **Ongoing: slow queries, bloat, security audit, capacity planning**
- **50 questions: fundamentals → performance → replication → backup → security**
- **Know the commands: EXPLAIN ANALYZE, CREATE INDEX CONCURRENTLY, pg_stat_statements**
- **Understand trade-offs: sync vs async, physical vs logical, VACUUM vs pg_repack**
- **Interview tip: show commands, not definitions. Trade-offs, not absolutes.**
- **Be honest about unknowns. Ask clarifying questions before answering.**


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
