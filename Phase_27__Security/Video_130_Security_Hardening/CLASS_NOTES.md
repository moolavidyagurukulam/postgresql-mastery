# Security Hardening
**Series:** PostgreSQL Mastery | **Phase:** Phase 27: Security | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous classes, we set up authentication, encrypted connections with SSL, protected data with encryption, and prevented SQL injection. But a default PostgreSQL installation still has many settings that are too permissive for production. Today we take a freshly installed PostgreSQL 16 server and harden it step by step — revoking unnecessary privileges, restricting network access, disabling dangerous features, and locking down every configuration file. By the end, you will have a complete hardening checklist that turns a default installation into a production-ready fortress. Let us begin.

### The Problem — Default Installation Is Not Secure
Here is a real scenario. A company installs PostgreSQL on a cloud server. They set up their application and it works fine. But they never changed the default settings. The postgres superuser has a weak password. The server listens on all network interfaces. Anyone on the network can attempt connections. Public schema allows any user to create objects. The pg_stat_statements extension logs query text including sensitive data. Six months later, an attacker scans the network, finds port 5432 open, brute-forces the postgres password, and has full superuser access. Everything — data, backups, configurations — is compromised. This is preventable with hardening.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should have completed the authentication, SSL, encryption, and SQL injection classes. Recap — in the previous class, we learned to prevent SQL injection using parameterized queries, format with percent-L and percent-I, and least-privilege roles. Now we go beyond the application layer and harden the server itself — because even with perfect application code, a misconfigured server is still vulnerable.

- Prerequisite: Authentication methods (pg_hba.conf)
- Prerequisite: SSL/TLS configuration
- Prerequisite: Encryption and SQL injection prevention
- Recap: Parameterized queries prevent injection
- Now: Hardening the server itself for production

### What is Security Hardening?
Security hardening means reducing the attack surface of your PostgreSQL server. It is the process of changing defaults, removing unnecessary permissions, and configuring protections so that even if an attacker gains partial access, the damage is limited. Think of it like a house — authentication is the front door lock, SSL is the alarm system, but hardening is also bolting the windows, removing the spare key from under the mat, and putting valuables in a safe. You need all of them.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Attack Surface** | Total number of points where an attacker could try to get in |
| **Hardening** | Reducing that surface by removing unnecessary access and features |
| **Defense in Depth** | Multiple layers so one breach does not compromise everything |
| **Least Privilege** | Every user and process gets only the minimum access it needs |

### Support This Free Course
If you are learning from this course, here is how to support it. Like this video so more people find it. Share it with someone learning PostgreSQL. Subscribe and hit the bell icon so you never miss a class. Download today's class materials from the link in the description — you can practice every command on your own server. And if this free course is helping you, consider supporting it through the donation link in the description. Every bit helps keep this course going. Now let us continue with more hardening steps.

- Like this video — helps others discover PostgreSQL Mastery
- Share with someone learning PostgreSQL
- Subscribe + bell icon for new classes
- Download class materials (link in description)
- Support this free course: donation link in description

### Default vs Hardened — Comparison
Here is a complete hardening checklist comparing a default installation versus a hardened one. Use this as your reference every time you set up a new PostgreSQL production server.

| Default Installation | Hardened Production |
| :--- | :--- |
| listen_addresses = '*' | listen_addresses = specific IPs |
| md5 password encryption | scram-sha-256 encryption |
| pg_hba.conf: host all all trust | pg_hba.conf: hostssl + reject default |
| PUBLIC can CREATE in public schema | CREATE revoked from PUBLIC |
| No connection limits | Per-role connection limits |
| No password expiry | VALID UNTIL on all roles |
| log_statement = 'none' | log_statement = 'ddl', connections logged |
| No firewall rules | ufw/iptables restrict port 5432 |
| SECURITY DEFINER unaudited | All SECURITY DEFINER audited + pinned |

### Hardening Decision Framework
When should you harden and when can you skip steps? For development environments, minimal hardening is fine — strong passwords and listen on localhost only. For staging, apply most production rules because staging should mirror production. For production, apply every single step on the checklist. And for cloud-managed databases like RDS or Cloud SQL, the cloud provider handles OS-level hardening, but you still need to configure pg_hba.conf, roles, passwords, and application-level security yourself.

| Environment | Hardening Level |
| :--- | :--- |
| Development: local laptop or VM | Minimal: strong passwords, localhost only |
| Staging: mirrors production setup | Full: apply all production rules |
| Production: real users, real data | Full: every checklist item, audited quarterly |
| Cloud-managed (RDS/Cloud SQL) | Partial: provider handles OS, you handle PG config |

### Practice Exercises
Here are your practice exercises. One — check your current pg_hba.conf and identify any lines using trust or md5. Replace them with scram-sha-256 and hostssl. Two — revoke CREATE on the public schema from PUBLIC, then test by connecting as a non-superuser and trying to create a table. Three — set connection limits and statement timeouts for an application role and test them. Four — find all SECURITY DEFINER functions in your database and verify they have SET search_path. Five — write a complete hardening script that you can run on any new PostgreSQL 16 installation.

- 1. Audit pg_hba.conf: replace trust/md5 with scram-sha-256 + hostssl
- 2. REVOKE CREATE ON SCHEMA public FROM PUBLIC — test as non-superuser
- 3. Set CONNECTION LIMIT and statement_timeout for a role — verify limits
- 4. Find all SECURITY DEFINER functions — check search_path is pinned
- 5. Write a reusable hardening script for new PG 16 installations


---

## 3. Hands-On Commands & psql Output

### The Problem — Default Installation Is Not Secure
**Explanation:** Here is a real scenario. A company installs PostgreSQL on a cloud server. They set up their application and it works fine. But they never changed the default settings. The postgres superuser has a weak password. The server listens on all network interfaces. Anyone on the network can attempt connections. Public schema allows any user to create objects. The pg_stat_statements extension logs query text including sensitive data. Six months later, an attacker scans the network, finds port 5432 open, brute-forces the postgres password, and has full superuser access. Everything — data, backups, configurations — is compromised. This is preventable with hardening.

```sql
-- Default PostgreSQL 16 installation risks:

1. postgres superuser with weak/default password
2. listen_addresses = '*' (accepts from anywhere)
3. pg_hba.conf too permissive (trust or md5)
4. Public schema: any user can CREATE objects
5. Superuser can COPY files to/from disk
6. No connection limits set
7. No password expiry or complexity rules
8. Log files may contain sensitive data

-- Attacker scans network, finds port 5432...
-- Brute-forces weak postgres password...
-- Full superuser access to everything.
```

### Step 1: Secure the Superuser
**Explanation:** Step one — secure the postgres superuser. The postgres role is like root on Linux — it can do anything. First, set a strong password using SCRAM-SHA-256. Then create a separate admin role for daily DBA work and use the postgres superuser only when absolutely necessary. Never let applications connect as postgres. And if possible, set the postgres role to NOLOGIN and use peer authentication from the local OS user only.

```sql
-- Set strong password for postgres (SCRAM-SHA-256):
postgres=# ALTER ROLE postgres WITH PASSWORD 'Str0ng!P@ss#2026-Prod';
ALTER ROLE

-- Verify password encryption method:
postgres=# SHOW password_encryption;
 password_encryption
---------------------
 scram-sha-256

-- Create a separate DBA admin role:
postgres=# CREATE ROLE dba_admin WITH LOGIN PASSWORD 'DbaStr0ng!2026' SUPERUSER;
CREATE ROLE

-- Optional: lock postgres from network login
-- In pg_hba.conf, only allow peer for postgres:
-- local  all  postgres  peer
-- (no hostssl line for postgres)
```

### Step 3: Production pg_hba.conf
**Explanation:** Step three — lock down pg_hba.conf. This file controls who can connect, from where, and how they authenticate. The rules are processed top to bottom, and the first match wins. Start with the most restrictive rules. Use hostssl instead of host to force encrypted connections. Use scram-sha-256 instead of md5 for passwords. Never use trust in production — it allows connections without any password. And explicitly reject everything that is not specifically allowed.

```sql
# TYPE   DATABASE   USER         ADDRESS          METHOD

# Local superuser — peer auth only (OS user must match)
local    all        postgres                      peer

# DBA admin — SSL + SCRAM from management subnet only
hostssl  all        dba_admin    10.0.2.0/24      scram-sha-256

# Application role — SSL + SCRAM from app servers only
hostssl  app_db     web_app      10.0.1.10/32     scram-sha-256
hostssl  app_db     web_app      10.0.1.11/32     scram-sha-256

# Replication — SSL + SCRAM from replica only
hostssl  replication repl_user   10.0.3.20/32     scram-sha-256

# Reject everything else explicitly
hostssl  all        all          0.0.0.0/0        reject
hostnossl all       all          0.0.0.0/0        reject
host     all        all          0.0.0.0/0        reject
```

### Step 4: Revoke Public Schema Permissions
**Explanation:** Step four — revoke public schema permissions. In PostgreSQL 16, the default behavior changed — the public schema no longer grants CREATE to all users by default. But if you upgraded from an older version, or if you want to be explicit, revoke CREATE on the public schema from PUBLIC. This prevents any user from creating tables, functions, or other objects in the public schema without explicit permission. Also revoke CONNECT from the public role on databases that should be restricted.

```sql
-- Check current public schema permissions:
postgres=# SELECT nspname, nspacl FROM pg_namespace WHERE nspname = 'public';
 nspname |              nspacl
---------+----------------------------------
 public  | {postgres=UC/postgres,=UC/postgres}

-- Revoke CREATE from PUBLIC on public schema:
postgres=# REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE

-- Revoke CONNECT on restricted databases:
postgres=# REVOKE CONNECT ON DATABASE app_db FROM PUBLIC;
REVOKE

-- Grant CONNECT only to specific roles:
postgres=# GRANT CONNECT ON DATABASE app_db TO web_app;
GRANT

-- Verify:
postgres=# SELECT nspname, nspacl FROM pg_namespace WHERE nspname = 'public';
 nspname |            nspacl
---------+------------------------------
 public  | {postgres=UC/postgres,=U/postgres}
```

### Step 5: Connection Limits & Timeouts
**Explanation:** Step five — set connection limits. Without limits, an attacker or a misbehaving application can exhaust all available connections, causing a denial-of-service. Set max_connections to a reasonable value — usually 100 to 200 for most workloads. Use PgBouncer for connection pooling if your application needs more. Set per-role connection limits so no single role can consume all connections. And set idle session timeouts to automatically disconnect forgotten sessions.

```sql
-- postgresql.conf: Set global connection limit
postgres=# ALTER SYSTEM SET max_connections = 150;
ALTER SYSTEM

-- Per-role connection limits:
postgres=# ALTER ROLE web_app CONNECTION LIMIT 50;
ALTER ROLE
postgres=# ALTER ROLE dba_admin CONNECTION LIMIT 5;
ALTER ROLE

-- Idle session timeout (PG 14+):
postgres=# ALTER SYSTEM SET idle_session_timeout = '10min';
ALTER SYSTEM

-- Statement timeout to kill long-running queries:
postgres=# ALTER ROLE web_app SET statement_timeout = '30s';
ALTER ROLE

postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
```

### Step 6: Disable Dangerous Features
**Explanation:** Step six — disable dangerous features. The COPY command with file paths allows a superuser to read or write any file on the server filesystem. If a superuser account is compromised, COPY TO and COPY FROM become data exfiltration tools. Restrict this by never granting superuser to application roles. Also disable the file_fdw extension unless needed — it provides the same filesystem access. And disable dblink and postgres_fdw for roles that do not need cross-database queries.

```sql
-- COPY with file path requires superuser:
postgres=# SET ROLE web_app;
SET
postgres=> COPY users TO '/tmp/stolen_data.csv';
ERROR:  must be superuser or have privileges of the pg_write_server_files role to COPY to a file
HINT:  Anyone can COPY to stdout or from stdin. psql's \copy command also works for anyone.

postgres=# RESET ROLE;
RESET

-- Revoke dangerous default roles from app users:
postgres=# REVOKE pg_read_server_files FROM web_app;
REVOKE
postgres=# REVOKE pg_write_server_files FROM web_app;
REVOKE
postgres=# REVOKE pg_execute_server_program FROM web_app;
REVOKE

-- Drop unneeded extensions:
-- DROP EXTENSION IF EXISTS file_fdw;
-- DROP EXTENSION IF EXISTS dblink;
```

### Step 8: Password Policies
**Explanation:** Step eight — configure password policies. PostgreSQL does not have built-in password complexity enforcement, but you can use the passwordcheck module or the more advanced credcheck extension. The passwordcheck module ships with PostgreSQL and enforces minimum length and checks against the username. For password expiry, set VALID UNTIL on roles so passwords must be rotated periodically.

```sql
-- Enable passwordcheck module in postgresql.conf:
-- shared_preload_libraries = 'passwordcheck'
-- (requires restart)

-- passwordcheck enforces:
-- - Minimum 8 characters
-- - Cannot be the username
-- - Must contain letters and non-letters

-- Set password expiry on roles:
postgres=# ALTER ROLE web_app VALID UNTIL '2027-06-01';
ALTER ROLE

-- Check role password expiry:
postgres=# SELECT rolname, rolvaliduntil FROM pg_roles WHERE rolvaliduntil IS NOT NULL;
 rolname  |      rolvaliduntil
----------+------------------------
 web_app  | 2027-06-01 00:00:00+00

-- Weak password test (with passwordcheck loaded):
-- ALTER ROLE web_app PASSWORD 'abc';
-- ERROR:  password is too short
```

### Step 9: RLS & SECURITY DEFINER Audit
**Explanation:** Step nine — restrict Row-Level Security defaults and SECURITY DEFINER functions. Row-Level Security is a powerful feature, but if you create policies on tables, make sure you also enable the force option for table owners. Without FORCE ROW LEVEL SECURITY, the table owner bypasses all policies. Also audit every SECURITY DEFINER function — these run with the privileges of the function creator, not the caller. Every SECURITY DEFINER function must have SET search_path equals public to prevent search path hijacking.

```sql
-- Force RLS even for table owner:
postgres=# ALTER TABLE sensitive_data FORCE ROW LEVEL SECURITY;
ALTER TABLE

-- Find all SECURITY DEFINER functions:
postgres=# SELECT n.nspname, p.proname, r.rolname AS owner
postgres-# FROM pg_proc p JOIN pg_roles r ON p.proowner = r.oid
postgres-# JOIN pg_namespace n ON p.pronamespace = n.oid
postgres-# WHERE p.prosecdef = true AND n.nspname NOT IN ('pg_catalog','information_schema');
 nspname |    proname     |  owner
---------+----------------+----------
 public  | admin_lookup   | postgres

-- Check if search_path is set:
postgres=# SELECT proname, proconfig FROM pg_proc WHERE prosecdef = true;
   proname     |        proconfig
---------------+--------------------------
 admin_lookup  | {search_path=public}
-- Good: search_path is pinned
```

### Step 10: OS-Level Hardening
**Explanation:** Step ten — configure the operating system layer. PostgreSQL security is only as strong as the OS underneath. Set file permissions on the data directory to 700 — only the postgres user should access it. Use a firewall to restrict port 5432 to only the IP addresses that need it. Disable core dumps in production to prevent sensitive data from ending up in crash files. And keep PostgreSQL and the OS updated with security patches.

```sql
-- Data directory permissions (Linux):
$ ls -la /var/lib/postgresql/16/
drwx------ 19 postgres postgres 4096 Nov  4 main
-- Must be 700 — no group or other access

-- Firewall: allow only app server and DBA subnet
$ sudo ufw allow from 10.0.1.10 to any port 5432
$ sudo ufw allow from 10.0.2.0/24 to any port 5432
$ sudo ufw deny 5432

-- Disable core dumps:
$ echo '* hard core 0' | sudo tee -a /etc/security/limits.conf
$ echo 'fs.suid_dumpable = 0' | sudo tee -a /etc/sysctl.conf

-- Keep PostgreSQL updated:
$ sudo apt update && sudo apt upgrade postgresql-16
```

### Step 11: Extension Management
**Explanation:** Step eleven — restrict extensions. Extensions run code inside the PostgreSQL server process. Only install extensions you actually need. Review installed extensions regularly. Some extensions like dblink, postgres_fdw, and file_fdw provide network or filesystem access that could be exploited. Only a superuser can install extensions, but once installed, their functions may be callable by any user unless you revoke permissions.

```sql
-- List all installed extensions:
postgres=# SELECT extname, extversion, extowner::regrole FROM pg_extension;
  extname   | extversion | extowner
-----------+------------+----------
 plpgsql   | 1.0        | postgres
 pgcrypto  | 1.3        | postgres

-- Remove extensions you do not need:
postgres=# DROP EXTENSION IF EXISTS dblink;
DROP EXTENSION

-- Restrict who can use an extension's functions:
postgres=# REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;
REVOKE
postgres=# GRANT EXECUTE ON FUNCTION pgp_sym_encrypt(text, text) TO web_app;
GRANT
```

### Beginner Traps — Hardening Mistakes
**Explanation:** Beginner trap number one — forgetting to reload after configuration changes. You edit postgresql.conf but nothing changes because you forgot to run SELECT pg_reload_conf or sudo systemctl reload postgresql. Some settings like max_connections and shared_preload_libraries require a full restart, not just a reload. Check the context column in pg_settings to know which one. Trap two — revoking from the wrong role. You revoke CREATE from a user but they can still create objects because they inherited the permission through a group role. Check pg_roles to trace role membership. Trap three — logging too much. Setting log_statement to all in production generates enormous log files and may contain sensitive query data. Use ddl for schema changes or mod for data-modifying statements.

```sql
-- Trap 1: Forgot to reload after config change
postgres=# ALTER SYSTEM SET idle_session_timeout = '10min';
ALTER SYSTEM
postgres=# SHOW idle_session_timeout;
 idle_session_timeout
----------------------
 0           <-- Still old value!
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t

-- Trap 2: Check which settings need restart vs reload
postgres=# SELECT name, context FROM pg_settings WHERE name = 'max_connections';
      name       | context
----------------+------------
 max_connections | postmaster   <-- Requires RESTART

-- Trap 3: log_statement = 'all' logs sensitive queries
-- Use 'ddl' for production, 'mod' if you need DML tracking
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — Step 2: Restrict listen_addresses
Step two — restrict network listening. By default, some installations set listen_addresses to star, meaning PostgreSQL accepts connections from any network interface. In production, restrict this to only the interfaces that need it. If your application runs on the same server, use localhost only. If your application is on a different server, list only the specific IP address of the database server's internal network interface. Never expose PostgreSQL directly to the internet. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `listen_addresses` | `'localhost'` | **`[RESTART]`** (Postmaster Restart) | Only local connections (app on same server) (Default: 'localhost') |
| `listen_addresses` | `'10.0.1.5'` | **`[RESTART]`** (Postmaster Restart) | Only internal network IP (app on other server) (Default: 'localhost') |
| `listen_addresses` | `'localhost,10.0.1.5'` | **`[RESTART]`** (Postmaster Restart) | Both local and one internal IP (Default: 'localhost') |
| `port` | `5432` | **`[RESTART]`** (Postmaster Restart) | Change from default if security-through-obscurity desired (Default: 5432) |
| `# NEVER use` | `'*'` | `[SETTING]` | Accepts from ALL interfaces — too broad for production |


### File: `postgresql.conf` — Step 7: Secure Logging Configuration
Step seven — secure logging. Logs are essential for security monitoring but must not leak sensitive data. Set log_statement to ddl so you catch schema changes but do not log every SELECT with potentially sensitive data. Set log_connections and log_disconnections to on for connection auditing. Set log_line_prefix to include the timestamp, user, database, and client IP. And protect the log directory permissions so only the postgres OS user can read them. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `log_destination` | `'stderr'` | `[RELOAD]` (Live Reload `SIGHUP`) | Or 'csvlog' for structured parsing (Default: 'stderr') |
| `logging_collector` | `on` | **`[RESTART]`** (Postmaster Restart) | Capture stderr into log files (Default: off) |
| `log_directory` | `'log'` | `[RELOAD]` (Live Reload `SIGHUP`) | Relative to data directory (Default: 'log') |
| `log_filename` | `'postgresql-%Y-%m-%d.log'` | `[RELOAD]` (Live Reload `SIGHUP`) | Daily rotation (Default: 'postgresql-%Y-%m-%d_%H%M%S.log') |
| `log_statement` | `'ddl'` | `[SETTING]` | Log DDL only — not sensitive queries |
| `log_connections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Log every new connection (Default: off) |
| `log_disconnections` | `on` | `[RELOAD]` (Live Reload `SIGHUP`) | Log every disconnect (Default: off) |
| `log_line_prefix` | `'%t [%p] %u@%d from %h '` | `[SETTING]` | time pid user@db from host |
| `log_min_duration_statement` | `1000` | `[RELOAD]` (Live Reload `SIGHUP`) | Log queries taking > 1 second (Default: -1) |
| `log_file_mode` | `0600` | `[SETTING]` | Only postgres can read logs |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Hardening Mistakes
Beginner trap number one — forgetting to reload after configuration changes. You edit postgresql.conf but nothing changes because you forgot to run SELECT pg_reload_conf or sudo systemctl reload postgresql. Some settings like max_connections and shared_preload_libraries require a full restart, not just a reload. Check the context column in pg_settings to know which one. Trap two — revoking from the wrong role. You revoke CREATE from a user but they can still create objects because they inherited the permission through a group role. Check pg_roles to trace role membership. Trap three — logging too much. Setting log_statement to all in production generates enormous log files and may contain sensitive query data. Use ddl for schema changes or mod for data-modifying statements.

```sql
-- Trap 1: Forgot to reload after config change
ALTER SYSTEM SET idle_session_timeout = '10min';
ALTER SYSTEM
SHOW idle_session_timeout;
 idle_session_timeout
----------------------
 0           <-- Still old value!
SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t

-- Trap 2: Check which settings need restart vs reload
SELECT name, context FROM pg_settings WHERE name = 'max_connections';
      name       | context
----------------+------------
 max_connections | postmaster   <-- Requires RESTART

-- Trap 3: log_statement = 'all' logs sensitive queries
-- Use 'ddl' for production, 'mod' if you need DML tracking
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. A default PostgreSQL installation is designed for ease of setup, not security. Hardening means restricting listen_addresses, locking down pg_hba.conf with hostssl and scram-sha-256, revoking public schema permissions, setting connection limits and timeouts, disabling dangerous features, configuring secure logging, managing password policies, auditing SECURITY DEFINER functions, and hardening the operating system with firewall rules and file permissions. Apply this checklist to every production server, and review it quarterly.

- **Default installation is NOT production-ready — always harden**
- **listen_addresses: restrict to specific IPs, never '*'**
- **pg_hba.conf: hostssl + scram-sha-256 + explicit reject**
- **REVOKE CREATE ON SCHEMA public FROM PUBLIC**
- **Connection limits + statement_timeout + idle_session_timeout**
- **Disable dangerous features: COPY file, dblink, file_fdw**
- **Logging: ddl + connections + log_line_prefix with user/host**
- **Password policies: passwordcheck + VALID UNTIL**
- **Audit SECURITY DEFINER functions + pin search_path**
- **OS: firewall, 700 on data dir, disable core dumps, patch regularly**


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
