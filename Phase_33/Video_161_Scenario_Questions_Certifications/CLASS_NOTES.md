# Scenario-Based Interview Questions & Certifications
**Series:** PostgreSQL Mastery | **Phase:** 33 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. This is the final class of the entire course. We cover scenario-based interview questions — the kind where the interviewer describes a production problem and you walk through the solution step by step. Then we cover PostgreSQL certifications and the best learning resources to continue your journey.

### Scenario Interview Questions
& Certifications
Welcome to PostgreSQL Mastery. This is the final class of the entire course. We cover scenario-based interview questions — the kind where the interviewer describes a production problem and you walk through the solution step by step. Then we cover PostgreSQL certifications and the best learning resources to continue your journey.

### How to Answer Scenario Questions
Scenario-based questions test how you think under pressure. The interviewer describes a production situation — database is slow, disk is full, replication is broken. You must walk through your diagnostic steps out loud. They want to see your troubleshooting methodology, not just the answer. Always follow the pattern: detect, diagnose root cause, fix, verify, and prevent. Let us practice with real scenarios.

- 1. Listen carefully — Identify symptoms vs root cause. Ask clarifying questions before jumping to solutions.
- 2. State your approach — Say: 'I would start by checking...' Shows structured thinking. Not random guessing.
- 3. Detect → Diagnose → Fix — Follow a systematic flow. Show you know the diagnostic queries and tools.
- 4. Verify the fix worked — Always say how you would confirm. 'Then I would run EXPLAIN ANALYZE to verify.'
- 5. Prevent recurrence — End with prevention: monitoring, alerts, configuration changes. Shows DBA maturity.

### Scenario 1: Database is Slow
Scenario: Users report the application is slow. Queries that took milliseconds now take seconds. Walk me through your investigation. Start with pg_stat_activity — find active queries and their duration. Check wait events — are queries waiting for locks or I/O? Use pg_stat_statements to find the top queries by total time. For the slowest query, run EXPLAIN ANALYZE — look for Seq Scans on large tables. Check if statistics are stale — run ANALYZE. Check if the table is bloated — high dead tuple count means VACUUM is behind.

### Scenario 2: Disk 95% Full
Scenario: Monitoring shows the database server is at 95 percent disk. What do you do? First, find where the space is. Check database sizes, then find the largest tables. Check if WAL is accumulating — a stuck replication slot can fill disk with WAL files. Check table bloat — dead tuples occupying space. For immediate relief: VACUUM large bloated tables, archive and delete old data in batches, drop unused indexes. Long term: add disk, partition old data, tune autovacuum.


---

## 2. Core Technical Concepts & Mechanisms

### How to Answer Scenario Questions
Scenario-based questions test how you think under pressure. The interviewer describes a production situation — database is slow, disk is full, replication is broken. You must walk through your diagnostic steps out loud. They want to see your troubleshooting methodology, not just the answer. Always follow the pattern: detect, diagnose root cause, fix, verify, and prevent. Let us practice with real scenarios.

- 1. Listen carefully — Identify symptoms vs root cause. Ask clarifying questions before jumping to solutions.
- 2. State your approach — Say: 'I would start by checking...' Shows structured thinking. Not random guessing.
- 3. Detect → Diagnose → Fix — Follow a systematic flow. Show you know the diagnostic queries and tools.
- 4. Verify the fix worked — Always say how you would confirm. 'Then I would run EXPLAIN ANALYZE to verify.'
- 5. Prevent recurrence — End with prevention: monitoring, alerts, configuration changes. Shows DBA maturity.

### Scenario 3: Primary Down at 3 AM
Scenario: You get an alert at 3 AM — primary PostgreSQL server is unreachable. You have one standby with streaming replication. What do you do? First, verify the primary is truly down — try pg_isready, try SSH. Do not rush to promote if it is just a network blip. Once confirmed, check the standby is up and its lag. Promote the standby. Redirect application traffic. Verify writes work. Then build a new standby as soon as possible — you are running without HA now.

- 1. Verify primary is down — pg_isready, SSH, ping. Try 3 times. Never promote on first try — split brain kills data.
- 2. Check standby health — pg_is_in_recovery() = true? pg_last_xact_replay_timestamp() — how current?
- 3. Promote standby — pg_ctl promote -D /data OR SELECT pg_promote(). Wait for confirmation.
- 4. Verify promotion — pg_is_in_recovery() = false. Test INSERT. Check application connections.
- 5. Redirect traffic — Update DNS / HAProxy / connection string. Verify app works on new primary.
- 6. Build new standby ASAP — pg_basebackup from new primary. You have NO HA until this is done.

### Scenario 4: Accidental DELETE Recovery
Scenario: A developer ran DELETE FROM orders without a WHERE clause. Two million rows deleted. They realized it 10 minutes ago. How do you recover? If the transaction is still open — ROLLBACK. If committed — Point-in-Time Recovery. Restore the last base backup, set recovery_target_time to just before the DELETE. This restores the entire database to that moment. Alternative: if you have a standby with a delay, query the standby for the missing data.

- If transaction still open — ROLLBACK; — data is saved. This is why we teach BEGIN before destructive operations.
- If committed (< 1 hour) — PITR: restore base backup → set recovery_target_time to just before DELETE.
- If delayed standby exists — Query the delayed standby. pg_dump the table from standby. Restore to primary.
- If no backup (worst case) — If VACUUM hasn't run: pg_dirtyread extension might recover dead rows. No guarantee.
- Prevention — GRANT DELETE only to roles that need it. statement_timeout. Require WHERE clause in app.

### Scenario 6: Connection Limit Hit
Scenario: Application error — too many connections for role app_user. Maximum connections reached. What is your immediate and long-term fix? Immediately: kill idle-in-transaction connections to free slots. Check who is consuming connections — is it one app, one user? Long-term: deploy PgBouncer for connection pooling. Set idle_in_transaction_session_timeout to auto-kill leaked transactions. Set per-role connection limits.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Immediate fix** | Kill idle-in-transaction: pg_terminate_backend(pid) WHERE state = 'idle in transaction'. |
| **Diagnose** | Connections by user/app/state: GROUP BY usename, application_name, state. |
| **Short-term** | Increase max_connections (requires restart). Set idle_in_transaction_session_timeout = 5min. |
| **Long-term** | Deploy PgBouncer in transaction mode. 1000 app conns → 25 DB conns. |
| **Prevention** | ALTER ROLE app_user CONNECTION LIMIT 100. Monitor with alerts at 80%. |

### Comparison
You have reached the final stretch of the entire PostgreSQL Mastery course. If this course has been valuable to you, please support it with a donation. It keeps this content free for everyone learning PostgreSQL worldwide. And do not forget to download all class materials from GitHub.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: All 289 class materials |
| UPI: Link in description | Scenario answer templates |
| Every donation helps! | Certification study guide |

### PostgreSQL Certifications
Now let us talk about certifications and how they help your career. PostgreSQL does not have an official certification from the PostgreSQL Global Development Group. But there are respected third-party certifications. The EnterpriseDB PostgreSQL Associate and Professional certifications are the most recognized. There is also the PostgreSQL CE certification. Certifications prove structured knowledge — especially valuable when you do not yet have years of production experience.

| Term | Meaning / Explanation |
| :--- | :--- |
| **EDB PostgreSQL Associate** | Entry-level. SQL, administration basics, backup. Good for career starters. |
| **EDB PostgreSQL Professional** | Advanced. Replication, performance, security, HA. For experienced DBAs. |
| **PostgreSQL CE** | Community-based certification. Covers core PostgreSQL skills. |
| **AWS Database Specialty** | Covers RDS/Aurora PostgreSQL. Good for cloud DBA roles. |
| **Do you need one?** | Helpful for first DBA job. Less important with 3+ years experience. Never a substitute for skills. |

### Top Learning Resources
The best resources to continue your PostgreSQL journey. The official PostgreSQL documentation is the gold standard — it is comprehensive and well-written. For books, PostgreSQL Up and Running by Regina Obe, and The Art of PostgreSQL by Dimitri Fontaine. For practice, use pgexercises.com. Join the PostgreSQL community on the pgsql-general mailing list and the PostgreSQL Slack. Attend PGConf events. And contribute to open source — even documentation contributions are valuable.

- Official Docs — postgresql.org/docs/16/ — the best database documentation in existence. Read it.
- Books — PostgreSQL Up and Running (Obe). The Art of PostgreSQL (Fontaine). Mastering PostgreSQL (Stuth).
- Practice — pgexercises.com for SQL practice. Build real projects: library, e-commerce, SaaS.
- Community — pgsql-general mailing list. PostgreSQL Slack. Stack Overflow [postgresql] tag.
- Conferences — PGConf.dev, PGConf EU, PGDay. Talks by PostgreSQL core developers. Networking.
- Open source — Contribute to PG extensions. Write blog posts. Help on mailing lists. Build reputation.

### PostgreSQL Career Paths
PostgreSQL skills open several career paths. Database Administrator — managing production PostgreSQL, backups, replication, performance. Database Developer — writing complex SQL, stored procedures, schema design. Data Engineer — building data pipelines with PostgreSQL as the backbone. Site Reliability Engineer — automating database operations, monitoring, infrastructure as code. Cloud Database Engineer — managing RDS, Aurora, Cloud SQL. And Solutions Architect — designing database architecture for applications.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Database Administrator** | Production management. Backups, HA, replication, security, performance tuning. |
| **Database Developer** | Schema design. Complex SQL. Functions, triggers, extensions. Application integration. |
| **Data Engineer** | ETL pipelines. Data warehousing. PostgreSQL + Kafka + Spark. Analytics platforms. |
| **SRE / DevOps** | Automation: Ansible/Terraform for PG. Monitoring: Prometheus + Grafana. IaC. |
| **Cloud DB Engineer** | AWS RDS/Aurora, Azure Flexible, GCP Cloud SQL. Multi-cloud, cost optimization. |
| **Solutions Architect** | Database architecture for applications. Scalability design. Technology selection. |

### Build Your DBA Portfolio
To get hired, you need a portfolio beyond certifications. Build the projects from this course — library management, e-commerce, multi-tenant SaaS. Set up a full HA cluster with Patroni. Write blog posts explaining what you learned — this demonstrates communication skills. Contribute to PostgreSQL extensions on GitHub. Create a GitHub repository with your DBA scripts — monitoring queries, backup scripts, alerting rules. Interviewers look at your GitHub before your resume.

- GitHub projects — Library DB, E-Commerce DB, Multi-tenant SaaS. Show schema design, functions, triggers.
- HA cluster lab — Patroni + etcd + HAProxy. Document setup. Show failover test results with timing.
- DBA scripts repository — Monitoring queries, backup scripts, alerting rules. Reusable tools show practical skill.
- Blog posts — Write about: EXPLAIN ANALYZE interpretation, bloat management, replication setup.
- Open source contributions — PG extensions, documentation fixes, community help. Builds reputation and network.

### Course Recap — 289 Classes
Let us look back at what you have learned across 289 classes. Phases 1 through 10: SQL fundamentals — SELECT, JOINs, subqueries, aggregation. Phases 11 through 20: administration — installation, configuration, users, backup, replication. Phases 21 through 27: advanced SQL — window functions, CTEs, JSONB, full-text, partitioning, extensions. Phases 28 through 31: production — performance tuning, monitoring, security, cloud deployment. Phase 32: real-world troubleshooting and projects. Phase 33: interview preparation and career. You now have a complete PostgreSQL education.

- Phases 1-10: SQL Foundations — SELECT, WHERE, JOINs, subqueries, aggregation, data types, constraints, functions.
- Phases 11-20: Administration — Install, config, users/roles, backup, restore, replication, VACUUM, monitoring.
- Phases 21-27: Advanced SQL — Window functions, CTEs, JSONB, full-text, partitioning, triggers, extensions.
- Phases 28-31: Production — Performance tuning, explain plans, security hardening, cloud (AWS/Azure/GCP).
- Phase 32: Real-World — Troubleshooting scenarios. Library, E-Commerce, Multi-Tenant, HA Cluster projects.
- Phase 33: Career — DBA tasks, 50 interview questions, scenario questions, certifications, resources.


---

## 3. Hands-On Commands & psql Output

### Scenario 1: Database is Slow
**Explanation:** Scenario: Users report the application is slow. Queries that took milliseconds now take seconds. Walk me through your investigation. Start with pg_stat_activity — find active queries and their duration. Check wait events — are queries waiting for locks or I/O? Use pg_stat_statements to find the top queries by total time. For the slowest query, run EXPLAIN ANALYZE — look for Seq Scans on large tables. Check if statistics are stale — run ANALYZE. Check if the table is bloated — high dead tuple count means VACUUM is behind.

```sql
-- Step 1: What's running right now?
myapp=> SELECT pid, now() - query_start AS duration,
  wait_event_type, left(query, 60) AS query
FROM pg_stat_activity WHERE state = 'active'
ORDER BY duration DESC LIMIT 5;

-- Step 2: Top slow queries over time
myapp=> SELECT left(query, 50), calls,
  round(mean_exec_time::numeric, 1) AS mean_ms
FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 5;

-- Step 3: EXPLAIN the worst query
myapp=> EXPLAIN (ANALYZE, BUFFERS) SELECT ...;
-- Look for: Seq Scan, high Rows Removed, disk reads

-- Step 4: Fix — add missing index
myapp=> CREATE INDEX CONCURRENTLY idx_fix ON orders(user_id, status);
```

### Scenario 2: Disk 95% Full
**Explanation:** Scenario: Monitoring shows the database server is at 95 percent disk. What do you do? First, find where the space is. Check database sizes, then find the largest tables. Check if WAL is accumulating — a stuck replication slot can fill disk with WAL files. Check table bloat — dead tuples occupying space. For immediate relief: VACUUM large bloated tables, archive and delete old data in batches, drop unused indexes. Long term: add disk, partition old data, tune autovacuum.

```sql
-- Step 1: Where is the space used?
myapp=> SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database ORDER BY pg_database_size(datname) DESC;

-- Step 2: Largest tables
myapp=> SELECT relname, pg_size_pretty(pg_total_relation_size(oid))
FROM pg_class WHERE relkind = 'r'
ORDER BY pg_total_relation_size(oid) DESC LIMIT 5;

-- Step 3: Check WAL accumulation
$ du -sh /var/lib/postgresql/16/main/pg_wal
8.5G   (if > 2GB, check replication slots)

-- Step 4: Drop stuck replication slot if needed
myapp=> SELECT slot_name, active FROM pg_replication_slots;
-- If inactive: pg_drop_replication_slot('stuck_slot');
```

### Scenario 5: Replication Lag Growing
**Explanation:** Scenario: Your standby is showing 30 seconds of replication lag and it is growing. Walk me through diagnosis. Check pg_stat_replication on the primary — is the standby connected? Is it receiving WAL but not replaying? Check the standby for long-running queries — hot_standby_feedback might be holding back replay. Check for bulk operations on the primary generating excessive WAL. The fix depends on the root cause — cancel blocking queries, increase max_standby_streaming_delay, or throttle the bulk operation.

```sql
-- On PRIMARY: check replication status
myapp=> SELECT client_addr, state,
  pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag
FROM pg_stat_replication;
 client_addr | state     | lag
-------------+-----------+--------
 10.0.1.20   | streaming | 45 MB

-- On STANDBY: check for blocking queries
standby=> SELECT pid, now() - query_start AS duration,
  left(query, 50) FROM pg_stat_activity
WHERE state = 'active' ORDER BY duration DESC;

-- Fix: cancel blocking query on standby
standby=> SELECT pg_cancel_backend(<pid>);
-- Lag should start recovering immediately
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Summary. For scenario questions: follow detect, diagnose, fix, verify, prevent. Always think out loud. Show your methodology, not just the answer. Mention specific commands and queries. For certifications: EDB Associate and Professional are most recognized. The official docs are your best study resource. For career: build projects, write blog posts, contribute to open source, and get your GitHub portfolio ready. PostgreSQL skills are in high demand worldwide.

- **Scenario questions: Detect → Diagnose → Fix → Verify → Prevent**
- **Think out loud. Show methodology. Mention specific commands.**
- **Certifications: EDB Associate (entry) and Professional (advanced)**
- **Best resource: official PostgreSQL docs at postgresql.org**
- **Career paths: DBA, DB Developer, Data Engineer, SRE, Cloud Engineer**
- **Build portfolio: projects, HA cluster lab, DBA scripts, blog posts**
- **PostgreSQL skills are in high demand — you are ready**


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
