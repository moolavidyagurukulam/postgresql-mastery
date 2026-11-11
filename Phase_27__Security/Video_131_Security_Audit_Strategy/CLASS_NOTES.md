# Security Audit Strategy
**Series:** PostgreSQL Mastery | **Phase:** Phase 27: Security | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous classes, we secured authentication, encrypted connections, protected data, prevented SQL injection, and hardened the server. But how do you know if all of that is actually working? How do you prove it to your team, your manager, or an auditor? Today we build a complete security audit strategy — using pgAudit for detailed logging, writing SQL queries that automatically check your security posture, and creating a repeatable audit process you can run weekly, monthly, or before any compliance review. Let us begin.

### The Problem — Security Drift
Here is the scenario. A company passes a security audit in January. They feel confident. Six months later, a developer creates a new role with superuser privileges for debugging and forgets to remove it. Another developer installs the dblink extension to run a one-time migration and leaves it installed. A DBA adds a temporary trust line in pg_hba.conf during an emergency and never reverts it. By July, the server has three security holes that did not exist in January. Without regular auditing, these drift undetected until the next breach or the next external audit — whichever comes first.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should have completed the security hardening class. Recap — in the previous class, we applied a complete hardening checklist — from restricting listen_addresses and pg_hba.conf to revoking public schema permissions and auditing SECURITY DEFINER functions. Now we verify that hardening with systematic auditing. Hardening without auditing is like locking the door but never checking if it is still locked.

- Prerequisite: Security hardening checklist completed
- Prerequisite: Logging configuration from previous class
- Recap: Applied 11-step hardening checklist
- Now: Verifying security with systematic auditing
- Hardening without auditing = door locked but never checked

### What is a Security Audit?
A security audit is a systematic review of your database security configuration. It answers three questions. First — is our hardening still in place? Second — has anything changed since the last audit? Third — are there any new risks we need to address? There are two types of auditing. Configuration auditing checks the settings, roles, and permissions right now. Activity auditing logs what actually happened — who accessed what data, when, and how. You need both.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Configuration Audit** | Check current settings, roles, and permissions against a baseline |
| **Activity Audit** | Log and review who accessed what data, when, and how |
| **Drift Detection** | Compare current state to last known-good state |
| **Compliance** | Prove to auditors that controls are in place and working |

### pgAudit vs log_statement
Let us start with pgAudit — the PostgreSQL Audit Extension. pgAudit provides detailed session and object audit logging that goes far beyond what log_statement offers. While log_statement equals all logs the raw SQL text, pgAudit categorizes operations by type — READ, WRITE, DDL, ROLE, FUNCTION — and can log access to specific objects. This makes it possible to answer questions like: who read the salary table last week? Or who modified role permissions?

| log_statement = 'all' | pgAudit |
| :--- | :--- |
| Logs raw SQL text | Categorizes: READ, WRITE, DDL, ROLE |
| No categorization | Object-level audit (specific tables) |
| Cannot filter by object | Session-level audit (per role) |
| Cannot filter by operation type | Structured log entries |
| Huge log volume | Configurable granularity |
| Hard to search and analyze | Easy to search and report on |

### pgAudit Log Classes
pgAudit log classes control what gets logged. READ logs SELECT and COPY TO. WRITE logs INSERT, UPDATE, DELETE, TRUNCATE, and COPY FROM. FUNCTION logs function calls and DO blocks. DDL logs all object definition changes — CREATE, ALTER, DROP. ROLE logs GRANT, REVOKE, CREATE ROLE, ALTER ROLE, DROP ROLE. MISC logs other commands like DISCARD, FETCH, CHECKPOINT. And ALL logs everything. For production, start with ddl plus role. Add write if you need data modification tracking. Only add read if compliance requires it — it generates enormous volume.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | pgAudit log classes control what gets logged |
| **Point 2** | READ logs SELECT and COPY TO |
| **WRITE logs INSERT** | UPDATE, DELETE, TRUNCATE, and COPY FROM |
| **Point 4** | FUNCTION logs function calls and DO blocks |
| **DDL logs all object definition changes** | CREATE, ALTER, DROP |
| **ROLE logs GRANT** | REVOKE, CREATE ROLE, ALTER ROLE, DROP ROLE |
| **MISC logs other commands like DISCARD** | FETCH, CHECKPOINT |
| **Point 8** | And ALL logs everything |

### Support This Free Course
If you are learning from this course, here is how to support it. Like this video so more people find it. Share it with someone learning PostgreSQL. Subscribe and hit the bell icon so you never miss a class. Download today's class materials from the link in the description — the complete audit queries are ready to copy and run. And if this free course is helping you, consider supporting it through the donation link in the description. Now let us continue with more audit techniques.

- Like this video — helps others discover PostgreSQL Mastery
- Share with someone learning PostgreSQL
- Subscribe + bell icon for new classes
- Download class materials (link in description)
- Support this free course: donation link in description

### Audit Frequency Framework
How often should you audit? For a startup or small team, run the configuration audit monthly and review pgAudit logs weekly. For enterprise or regulated environments, run the configuration audit weekly and have real-time log monitoring with tools like ELK Stack or Splunk. After any emergency change — like adding a temporary trust rule — audit immediately once the emergency is resolved. And before any compliance review, run the full audit report and fix any failures.

| Environment | Audit Schedule |
| :--- | :--- |
| Startup / small team | Config: monthly, Logs: weekly |
| Enterprise / regulated | Config: weekly, Logs: real-time (ELK/Splunk) |
| After emergency change | Full audit immediately after resolution |
| Before compliance review | Full audit + fix all failures beforehand |
| After PostgreSQL upgrade | Full audit — settings may reset to defaults |

### Practice Exercises
Here are your practice exercises. One — install pgAudit, configure it for DDL plus ROLE logging, then create a table, grant permissions, and verify the audit log entries appear. Two — set up object-level auditing on a sensitive table and verify that SELECT queries are logged. Three — run the complete security scorecard query on your server and fix any FAIL results. Four — write a shell script that runs the audit report and saves it with today's date in the filename. Five — compare two audit reports from different dates and identify what changed.

- 1. Install pgAudit, set log='ddl,role', verify log entries appear
- 2. Set up object-level audit on a table — verify SELECT is logged
- 3. Run the security scorecard query — fix any FAIL results
- 4. Write a shell script: run audit + save with dated filename
- 5. Compare two audit reports — identify security drift


---

## 3. Hands-On Commands & psql Output

### The Problem — Security Drift
**Explanation:** Here is the scenario. A company passes a security audit in January. They feel confident. Six months later, a developer creates a new role with superuser privileges for debugging and forgets to remove it. Another developer installs the dblink extension to run a one-time migration and leaves it installed. A DBA adds a temporary trust line in pg_hba.conf during an emergency and never reverts it. By July, the server has three security holes that did not exist in January. Without regular auditing, these drift undetected until the next breach or the next external audit — whichever comes first.

```sql
-- January: server passes security audit

-- March: developer creates debug role
CREATE ROLE debug_user WITH LOGIN SUPERUSER PASSWORD 'debug123';
-- Meant to be temporary... never removed

-- May: migration needs dblink
CREATE EXTENSION dblink;
-- Migration done... extension stays

-- June: emergency access needed
-- pg_hba.conf: host all all 0.0.0.0/0 trust
-- Emergency resolved... trust line stays

-- July: 3 security holes that did not exist in January
-- No one knows until the next breach or audit
```

### Installing and Configuring pgAudit
**Explanation:** Installing pgAudit. On Debian and Ubuntu, install the package for your PostgreSQL version. Then add pgaudit to shared_preload_libraries in postgresql.conf. This requires a full restart — not just a reload. After the restart, create the extension in each database you want to audit. Then configure what to audit with pgaudit.log. The most common production setting is ddl plus role — this logs all schema changes and role modifications without the volume of logging every SELECT.

```sql
-- Install pgAudit (Debian/Ubuntu):
$ sudo apt install postgresql-16-pgaudit

-- Add to postgresql.conf:
-- shared_preload_libraries = 'pgaudit'

-- Restart PostgreSQL (required for shared_preload_libraries):
$ sudo systemctl restart postgresql-16

-- Create extension in each database:
postgres=# CREATE EXTENSION pgaudit;
CREATE EXTENSION

-- Configure audit logging:
postgres=# ALTER SYSTEM SET pgaudit.log = 'ddl, role';
ALTER SYSTEM
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
```

### pgAudit Log Entries — Real Examples
**Explanation:** Here is what pgAudit log entries look like in practice. Each entry includes the audit type, the statement class, the command tag, the object type and name, and the full SQL statement. This structured format makes it easy to search with grep or import into a log analysis tool. Notice how a CREATE TABLE statement is logged as DDL with the object type TABLE and the specific table name. And a GRANT is logged as ROLE with the exact privilege change.

```sql
-- DDL audit entry (CREATE TABLE):
2026-11-04 14:30:15 UTC [1234] postgres@app_db
  AUDIT: SESSION,1,1,DDL,CREATE TABLE,TABLE,public.orders,
  "CREATE TABLE orders (id serial, total numeric);"

-- ROLE audit entry (GRANT):
2026-11-04 14:32:00 UTC [1234] postgres@app_db
  AUDIT: SESSION,2,1,ROLE,GRANT,,,
  "GRANT SELECT ON orders TO web_app;"

-- WRITE audit entry (if pgaudit.log includes 'write'):
2026-11-04 14:35:00 UTC [5678] web_app@app_db
  AUDIT: SESSION,3,1,WRITE,INSERT,TABLE,public.orders,
  "INSERT INTO orders (total) VALUES (99.99);"
```

### Object-Level Auditing with pgAudit
**Explanation:** pgAudit also supports object-level auditing. Instead of logging all operations in a session, you can audit specific tables. Create an auditor role, grant it SELECT on the tables you want to monitor, and set pgaudit.role to that auditor role. Now any SELECT on those tables is logged — even if your session-level pgaudit.log does not include READ. This is perfect for compliance requirements like HIPAA or GDPR where you must track access to specific sensitive tables.

```sql
-- Create an auditor role (no login needed):
postgres=# CREATE ROLE pgaudit_auditor NOLOGIN;
CREATE ROLE

-- Grant SELECT on sensitive tables to auditor:
postgres=# GRANT SELECT ON patients TO pgaudit_auditor;
GRANT
postgres=# GRANT SELECT, INSERT, UPDATE, DELETE ON salary TO pgaudit_auditor;
GRANT

-- Set the audit role in postgresql.conf:
postgres=# ALTER SYSTEM SET pgaudit.role = 'pgaudit_auditor';
ALTER SYSTEM
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t

-- Now ANY SELECT on patients is logged:
-- AUDIT: OBJECT,4,1,READ,SELECT,TABLE,public.patients,...
```

### Audit Query 1: Superuser & Role Check
**Explanation:** Now let us build automated configuration audit queries. These SQL queries check your security posture in seconds. Run them weekly or before any compliance review. The first query checks for roles with superuser privileges — in production, you should have only one or two. The second checks for roles without password expiry. The third checks for dangerous default permissions.

```sql
-- Find all superuser roles:
SELECT rolname, rolcanlogin, rolvaliduntil
FROM pg_roles
WHERE rolsuper = true
ORDER BY rolname;
-- Expected: only 'postgres' and maybe 'dba_admin'

-- Find roles with no password expiry:
SELECT rolname, rolcanlogin,
  CASE WHEN rolvaliduntil IS NULL THEN 'NO EXPIRY'
       WHEN rolvaliduntil < now() THEN 'EXPIRED'
       ELSE rolvaliduntil::text
  END AS password_status
FROM pg_roles
WHERE rolcanlogin = true
ORDER BY rolvaliduntil NULLS FIRST;

-- Find roles that can bypass RLS:
SELECT rolname FROM pg_roles
WHERE rolbypassrls = true AND rolname != 'postgres';
```

### Audit Query 2: Configuration Scorecard
**Explanation:** The next set of audit queries checks your server configuration settings. These verify that the hardening from the previous class is still in place. Check password_encryption is scram-sha-256. Check SSL is on. Check log_connections and log_disconnections are enabled. Check that listen_addresses is not set to star. And check that idle_session_timeout has a value. Run all of these in one query and you get an instant security scorecard.

```sql
SELECT name AS setting,
  CASE
    WHEN name = 'password_encryption' AND setting = 'scram-sha-256' THEN 'PASS'
    WHEN name = 'ssl' AND setting = 'on' THEN 'PASS'
    WHEN name = 'log_connections' AND setting = 'on' THEN 'PASS'
    WHEN name = 'log_disconnections' AND setting = 'on' THEN 'PASS'
    WHEN name = 'log_statement' AND setting IN ('ddl','mod','all') THEN 'PASS'
    WHEN name = 'listen_addresses' AND setting != '*' THEN 'PASS'
    WHEN name = 'idle_session_timeout' AND setting != '0' THEN 'PASS'
    ELSE 'FAIL: ' || setting
  END AS status
FROM pg_settings
WHERE name IN (
  'password_encryption', 'ssl', 'log_connections',
  'log_disconnections', 'log_statement',
  'listen_addresses', 'idle_session_timeout'
)
ORDER BY status DESC, name;
```

### Audit Query 3: Extensions & Functions
**Explanation:** More audit queries. Check for installed extensions — especially dangerous ones like dblink, file_fdw, and postgres_fdw that provide network or filesystem access. Check for SECURITY DEFINER functions without a pinned search_path. Check for tables that have RLS enabled but no policies defined — this means the table is locked out for everyone except the owner. And check the public schema for unexpected objects.

```sql
-- Check for dangerous extensions:
SELECT extname, extversion FROM pg_extension
WHERE extname IN ('dblink', 'file_fdw', 'postgres_fdw',
                  'adminpack', 'lo')
ORDER BY extname;
-- If any appear, verify they are still needed

-- SECURITY DEFINER functions missing search_path:
SELECT n.nspname, p.proname, r.rolname AS owner
FROM pg_proc p
JOIN pg_roles r ON p.proowner = r.oid
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE p.prosecdef = true
  AND n.nspname NOT IN ('pg_catalog', 'information_schema')
  AND (p.proconfig IS NULL
    OR NOT EXISTS (
      SELECT 1 FROM unnest(p.proconfig) c
      WHERE c LIKE 'search_path=%'));
```

### Audit Query 4: pg_hba.conf Review
**Explanation:** Here is an audit query for connection security. This checks pg_hba.conf through the pg_hba_file_rules view — available in PostgreSQL 16. You can see every rule, its authentication method, and the address range. Look for any rules using trust — those should never exist in production. Look for rules using md5 — upgrade them to scram-sha-256. And look for rules with overly broad address ranges like 0.0.0.0/0 that use methods other than reject.

```sql
postgres=# SELECT line_number, type, database, user_name, address, auth_method
postgres-# FROM pg_hba_file_rules ORDER BY line_number;
 line_number |  type   | database | user_name |   address    | auth_method
-------------+---------+----------+-----------+--------------+----------------
           1 | local   | {all}    | {postgres}|              | peer
           2 | hostssl | {all}    | {dba_admin}| 10.0.2.0/24 | scram-sha-256
           3 | hostssl | {app_db} | {web_app} | 10.0.1.10/32 | scram-sha-256
           4 | hostssl | {all}    | {all}     | 0.0.0.0/0    | reject

-- RED FLAGS to look for:
postgres=# SELECT line_number, type, auth_method, address FROM pg_hba_file_rules
postgres-# WHERE auth_method IN ('trust', 'md5', 'password');
 line_number | type | auth_method | address
-------------+------+-------------+---------
(0 rows)   <-- Good: no weak auth methods found
```

### Complete Security Audit Report Query
**Explanation:** Now let us build a complete security audit report. This single query produces a full scorecard you can save and compare over time. It checks seven categories — authentication, encryption, logging, roles, extensions, functions, and connection settings. Each check returns PASS or FAIL with details. Save the output to a file with psql's backslash-o command and you have a timestamped audit record.

```sql
-- Save output: \o /tmp/audit_2026-11-04.txt

SELECT 'AUTH: password_encryption' AS check,
  CASE WHEN setting = 'scram-sha-256' THEN 'PASS'
       ELSE 'FAIL: ' || setting END AS result
FROM pg_settings WHERE name = 'password_encryption'
UNION ALL
SELECT 'AUTH: superuser count',
  CASE WHEN count(*) <= 2 THEN 'PASS: ' || count(*)
       ELSE 'FAIL: ' || count(*) || ' superusers' END
FROM pg_roles WHERE rolsuper = true
UNION ALL
SELECT 'SSL: enabled',
  CASE WHEN setting = 'on' THEN 'PASS'
       ELSE 'FAIL: SSL off' END
FROM pg_settings WHERE name = 'ssl'
UNION ALL
SELECT 'LOG: connections tracked',
  CASE WHEN setting = 'on' THEN 'PASS'
       ELSE 'FAIL' END
FROM pg_settings WHERE name = 'log_connections'
UNION ALL
SELECT 'EXT: dangerous extensions',
  CASE WHEN count(*) = 0 THEN 'PASS: none found'
       ELSE 'WARN: ' || string_agg(extname, ', ') END
FROM pg_extension
WHERE extname IN ('dblink','file_fdw','adminpack');
```

### Beginner Traps — Auditing Mistakes
**Explanation:** Beginner trap number one — trusting pgAudit log entries without protecting the logs themselves. If an attacker gains access, they can modify or delete log files to cover their tracks. Store audit logs on a separate filesystem or ship them to a remote log server in real time using syslog or a log agent. Trap two — auditing too much. Setting pgaudit.log to ALL in production creates gigabytes of logs per day and can impact performance. Start with ddl plus role, add write only if needed. Trap three — running audit queries but not saving the results. If you do not save each audit's output, you cannot detect drift between audits. Always save to a file with a date in the name.

```sql
-- Trap 1: Audit logs on same disk as data
-- Attacker with superuser access can:
-- ALTER SYSTEM SET logging_collector = off;
-- SELECT pg_reload_conf();
-- Fix: Ship logs to remote syslog server in real-time
-- log_destination = 'syslog'
-- syslog_facility = 'LOCAL0'

-- Trap 2: pgaudit.log = 'all' in production
-- 10,000 queries/sec = massive log volume + I/O overhead
-- Fix: 'ddl, role' for most, add 'write' only if needed

-- Trap 3: Running audits but not saving results
-- No historical comparison = no drift detection
-- Fix: Save every audit:
-- \o /var/log/pg_audit/audit_2026-11-04.txt
-- Run all audit queries...
-- \o
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Auditing Mistakes
Beginner trap number one — trusting pgAudit log entries without protecting the logs themselves. If an attacker gains access, they can modify or delete log files to cover their tracks. Store audit logs on a separate filesystem or ship them to a remote log server in real time using syslog or a log agent. Trap two — auditing too much. Setting pgaudit.log to ALL in production creates gigabytes of logs per day and can impact performance. Start with ddl plus role, add write only if needed. Trap three — running audit queries but not saving the results. If you do not save each audit's output, you cannot detect drift between audits. Always save to a file with a date in the name.

```sql
-- Trap 1: Audit logs on same disk as data
-- Attacker with superuser access can:
-- ALTER SYSTEM SET logging_collector = off;
-- SELECT pg_reload_conf();
-- Fix: Ship logs to remote syslog server in real-time
-- log_destination = 'syslog'
-- syslog_facility = 'LOCAL0'

-- Trap 2: pgaudit.log = 'all' in production
-- 10,000 queries/sec = massive log volume + I/O overhead
-- Fix: 'ddl, role' for most, add 'write' only if needed

-- Trap 3: Running audits but not saving results
-- No historical comparison = no drift detection
-- Fix: Save every audit:
-- \o /var/log/pg_audit/audit_2026-11-04.txt
-- Run all audit queries...
-- \o
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. Security auditing catches the drift that happens between hardening checkpoints. pgAudit provides structured, categorized audit logging — use DDL plus ROLE as a baseline, add WRITE for data tracking, and use object-level auditing for sensitive tables. Build a configuration scorecard query that checks all hardening settings in one run. Review pg_hba.conf rules, role privileges, extensions, and SECURITY DEFINER functions. Save every audit report with a timestamp for historical comparison. And protect the audit logs themselves by shipping them to a remote server. Audit regularly — monthly at minimum, weekly for regulated environments.

- **Security drift happens — regular auditing catches it**
- **pgAudit: structured logging — ddl + role baseline**
- **Object-level audit: track access to specific sensitive tables**
- **Configuration scorecard: one query checks all hardening settings**
- **Audit pg_hba.conf via pg_hba_file_rules for weak methods**
- **Check roles: superusers, expiry, connection limits, RLS bypass**
- **Review extensions and SECURITY DEFINER functions every audit**
- **Save timestamped audit reports for drift detection**
- **Protect logs: remote syslog, separate filesystem**
- **Frequency: monthly minimum, weekly for regulated environments**


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
