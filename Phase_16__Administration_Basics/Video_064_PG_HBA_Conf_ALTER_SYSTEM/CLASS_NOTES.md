# pg_hba.conf & ALTER SYSTEM
**Series:** PostgreSQL Mastery | **Phase:** Phase 16: Administration Basics | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover three critical topics. First, pg_hba.conf — the file that controls who can connect to PostgreSQL, from where, and how they authenticate. Second, pg_ident.conf — the file that maps operating system usernames to PostgreSQL roles. Third, ALTER SYSTEM — the safe way to change postgresql.conf parameters without editing the file directly. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### pg_hba.conf — Host-Based Authentication
pg_hba.conf stands for Host-Based Authentication. Every time someone tries to connect to PostgreSQL, this file decides: is this connection allowed, and how should the user prove their identity? The file is read top to bottom — the first matching line wins. If no line matches, the connection is rejected. This means the order of lines matters enormously. A common mistake is putting a reject rule after an allow rule, making the reject useless because the allow matches first.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Purpose** | Controls WHO can connect, from WHERE, to WHICH database, using WHAT authentication |
| **Location** | Same directory as postgresql.conf (data directory) |
| **Match Order** | First matching line wins — ORDER MATTERS |
| **No Match** | Connection rejected if no line matches |

**Notes:**
- Changes require reload: SELECT pg_reload_conf();
- Does NOT require restart

### Authentication Methods
Authentication methods. trust means no password required — anyone who can connect is automatically allowed in. NEVER use this in production. scram-sha-256 is the modern secure password method — the password is hashed and never sent in plain text. md5 is the older password method — still common but scram-sha-256 is better. peer uses the operating system username to authenticate — only works for local Unix socket connections. reject explicitly denies the connection. cert requires an SSL client certificate.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Authentication methods |
| **trust means no password required** | anyone who can connect is automatically allowed in |
| **Point 3** | NEVER use this in production |
| **Point 4** | scram-sha-256 is the modern secure password method — the password is hashed and never sent in plain text |
| **md5 is the older password method** | still common but scram-sha-256 is better |
| **Point 6** | peer uses the operating system username to authenticate — only works for local Unix socket connections |
| **Point 7** | reject explicitly denies the connection |
| **Point 8** | cert requires an SSL client certificate |

### Beginner Trap: Match Order Mistake
Here is a critical beginner trap: match order mistakes. Suppose you want to block user 'intern' from connecting to the production database, but allow all other users. If you write the allow-all rule first and the reject rule second, the intern matches the allow-all rule and gets in — the reject rule never fires. The fix: put specific deny rules BEFORE general allow rules. Always put reject rules at the top of the relevant section.

| WRONG (intern gets in!) | CORRECT (intern blocked) |
| :--- | :--- |
| host all all 10.0.0.0/8 scram-sha-256 | host all intern 10.0.0.0/8 reject |
| host all intern 10.0.0.0/8 reject | host all all 10.0.0.0/8 scram-sha-256 |
|  |  |
| intern matches line 1 FIRST | intern matches REJECT first |
| Line 2 never reached! | Others match allow on line 2 |

### ALTER SYSTEM — Safe Parameter Changes
Now ALTER SYSTEM — the recommended way to change postgresql.conf parameters. Instead of editing the file with a text editor, you run ALTER SYSTEM SET from psql. PostgreSQL writes the change to a separate file called postgresql.auto.conf, which overrides postgresql.conf on reload or restart. This is safer because PostgreSQL validates the value before writing it — you cannot make a syntax error.

| Term | Meaning / Explanation |
| :--- | :--- |
| **ALTER SYSTEM SET** | Changes a parameter — writes to postgresql.auto.conf |
| **ALTER SYSTEM RESET** | Removes a parameter override — reverts to postgresql.conf value |
| **postgresql.auto.conf** | Auto-generated file that overrides postgresql.conf settings |
| **Validation** | PostgreSQL validates the value BEFORE writing — prevents typos |

**Notes:**
- Still need pg_reload_conf() or restart after ALTER SYSTEM
- postgresql.auto.conf is read AFTER postgresql.conf (overrides)

### Beginner Trap: auto.conf Overrides Manual Edits
Here is a beginner trap with ALTER SYSTEM: you edit postgresql.conf directly, but ALTER SYSTEM already has an override in postgresql.auto.conf. Your edit has no effect because auto.conf wins. You spend hours wondering why your change does not apply. Always check postgresql.auto.conf when a manual edit seems to be ignored.

- 1 -- Written to postgresql.auto.conf
- 2 -- Set work_mem = '128MB' in the file
- 3 -- SELECT pg_reload_conf();
- 4 -- Still shows 64MB! auto.conf overrides the manual edit
- 5 -- Removes auto.conf override, then manual edit takes effect

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us look at the decision framework.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Decision Framework: Config Files
Here is the decision framework for the three config files. When should you edit which file, and when should you use ALTER SYSTEM?

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the decision framework for the three config files |
| **When should you edit which file** | and when should you use ALTER SYSTEM? |

### pg_hba.conf Security Checklist
Here is a security checklist for pg_hba.conf. Follow these rules for any production PostgreSQL installation.

- 1 -- trust = no password = anyone on that network gets full access
- 2 -- SCRAM is the modern standard — set password_encryption = 'scram-sha-256'
- 3 -- host all postgres 127.0.0.1/32 scram-sha-256 — ONLY localhost
- 4 -- /32 for single host, /24 for subnet — never /0 with allow
- 5 -- host all all 0.0.0.0/0 reject — catch-all safety net
- 6 -- host replication replicator standby_ip/32 scram-sha-256

### Practice Exercises
Time to practice. First, run SHOW hba_file and examine your pg_hba.conf using pg_hba_file_rules. Second, use ALTER SYSTEM to set log_min_duration_statement to 500 milliseconds, reload, and verify with SHOW. Third, use ALTER SYSTEM RESET to undo the change. Fourth, query pg_settings to find all parameters where pending_restart is true. Fifth, write a pg_hba.conf rule that allows user analyst to connect to reporting_db from 192.168.1.0 slash 24 using scram-sha-256.

- 1 -- SELECT * FROM pg_hba_file_rules ORDER BY line_number;
- 2 -- ALTER SYSTEM SET log_min_duration_statement = 500; then reload and SHOW
- 3 -- ALTER SYSTEM RESET log_min_duration_statement; then reload and verify
- 4 -- SELECT name, setting FROM pg_settings WHERE pending_restart = true;
- 5 -- host reporting_db analyst 192.168.1.0/24 scram-sha-256


---

## 3. Hands-On Commands & psql Output

### pg_hba.conf Line Format
**Explanation:** Each line in pg_hba.conf has a specific format: connection type, database, user, address, and authentication method. Let us break down each field. TYPE can be local for Unix socket connections, host for TCP/IP connections, hostssl for SSL-only TCP, and hostnossl for non-SSL TCP. DATABASE can be a specific database name, all, sameuser, or samerole. USER can be a specific role name, all, or a group name prefixed with plus sign. ADDRESS is the IP address or range using CIDR notation for host connections.

```sql
# TYPE    DATABASE  USER      ADDRESS         METHOD

# Local socket connections (Unix only):
local     all       all                         peer

# IPv4 local connections:
host      all       all       127.0.0.1/32     scram-sha-256

# IPv4 LAN connections:
host      all       all       192.168.1.0/24   scram-sha-256

# IPv6 local connections:
host      all       all       ::1/128          scram-sha-256

# Reject everything else (safety net):
host      all       all       0.0.0.0/0        reject
```

### Finding and Reading pg_hba.conf
**Explanation:** Let us find and read the actual pg_hba.conf file on your system. You can query PostgreSQL for its location, then look at what is in it.

```sql
postgres=# SHOW hba_file;
                hba_file
----------------------------------------------
 C:/Program Files/PostgreSQL/16/data/pg_hba.conf
(1 row)
postgres=# SELECT line_number, type, database, user_name, address, auth_method
FROM pg_hba_file_rules ORDER BY line_number;
 line_number | type  | database | user_name |  address    | auth_method
-------------+-------+----------+-----------+-------------+--------------
          85 | local | {all}    | {all}     |             | scram-sha-256
          87 | host  | {all}    | {all}     | 127.0.0.1/32| scram-sha-256
          89 | host  | {all}    | {all}     | ::1/128     | scram-sha-256
(3 rows)
```

### Production pg_hba.conf Example
**Explanation:** Let us walk through a real-world pg_hba.conf configuration. First, we allow the postgres superuser from localhost only. Then we allow our web application role from the application server's IP range. Then we allow read-only reporting from the office network. Finally, we reject everything else. Remember: first match wins, so the order is critical. We put specific rules before general ones.

```sql
# TYPE    DATABASE      USER          ADDRESS          METHOD

# Superuser: localhost only
host      all           postgres      127.0.0.1/32     scram-sha-256

# Web app: from app servers only
host      myapp_db      webapp        10.0.1.0/24      scram-sha-256

# Reporting: office network, read-only DB
host      reporting_db  analyst       192.168.10.0/24  scram-sha-256

# Replication: from standby server
host      replication   replicator    10.0.2.10/32     scram-sha-256

# Block everything else
host      all           all           0.0.0.0/0        reject
host      all           all           ::0/0            reject
```

### Verifying pg_hba.conf Before Reload
**Explanation:** You can verify your pg_hba.conf changes before reloading by querying pg_hba_file_rules. This view parses the file and shows any errors. If there is a syntax error, the error column will tell you exactly what is wrong and on which line. Always check this before reloading.

```sql
postgres=# -- Check for errors in the file:
postgres=# SELECT line_number, error FROM pg_hba_file_rules WHERE error IS NOT NULL;
 line_number | error
-------------+-------
(0 rows)
-- -- No errors! Safe to reload.
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
(1 row)
-- -- Existing connections are NOT affected by reload.
-- -- Only new connections use the new rules.
```

### Beginner Trap: Connection Refused After Edit
**Explanation:** Another beginner trap: you edit pg_hba.conf, reload, and your application still cannot connect. The error says FATAL: no pg_hba.conf entry for host, user, database. This means no line matched. Common causes: the IP address is wrong, you used IPv4 format but the client connects over IPv6, or you forgot that localhost on some systems resolves to the IPv6 address colon colon 1 instead of 127.0.0.1. Always add rules for both IPv4 and IPv6.

```sql
-- -- Error when connecting:
FATAL:  no pg_hba.conf entry for host "192.168.1.50",
  user "webapp", database "myapp", no encryption
-- 
-- -- Common causes:
-- -- 1. Wrong CIDR: used /32 instead of /24 for a range
-- -- 2. IPv4 vs IPv6: client connects as ::1, rule says 127.0.0.1
-- -- 3. Wrong database name in the rule
-- -- 4. Forgot to reload after editing
-- 
-- -- Fix: always include BOTH IPv4 and IPv6:
-- -- host all all 127.0.0.1/32 scram-sha-256
-- -- host all all ::1/128      scram-sha-256
```

### pg_ident.conf — OS User Mapping
**Explanation:** Now pg_ident.conf. This file maps operating system usernames to PostgreSQL role names. It is used when the authentication method is peer or ident. For example, the Linux user www-data might need to connect as PostgreSQL role webapp. The mapping has three fields: a map name, the OS username, and the PostgreSQL role. You reference the map name in pg_hba.conf using map equals mapname.

```sql
# pg_ident.conf
# MAPNAME       SYSTEM-USERNAME    PG-USERNAME

mymap           www-data           webapp
mymap           deploy             webapp
mymap           root               postgres
adminmap        john               admin_role
adminmap        jane               admin_role

# In pg_hba.conf, reference the map:
# local  myapp_db  webapp  peer  map=mymap
# This lets OS users www-data and deploy
# connect as PG role webapp
```

### Checking pg_ident.conf
**Explanation:** Let us find and check your pg_ident.conf. You can also verify the mappings from within PostgreSQL using the pg_ident_file_mappings view, which is available in PostgreSQL 16.

```sql
postgres=# SHOW ident_file;
                ident_file
----------------------------------------------
 C:/Program Files/PostgreSQL/16/data/pg_ident.conf
(1 row)
postgres=# SELECT line_number, map_name, sys_name, pg_username, error
FROM pg_ident_file_mappings ORDER BY line_number;
 line_number | map_name | sys_name | pg_username | error
-------------+----------+----------+-------------+------
(0 rows)
-- -- Empty by default — no OS-to-PG mappings configured yet
```

### Using ALTER SYSTEM
**Explanation:** Let us use ALTER SYSTEM to change some parameters. We will set work_mem and log_min_duration_statement, then reload. After reload, we verify the changes took effect. Notice that ALTER SYSTEM validates the value — if you try to set shared_buffers to a nonsense value, it gives an error immediately.

```sql
postgres=# ALTER SYSTEM SET work_mem = '64MB';
ALTER SYSTEM
postgres=# ALTER SYSTEM SET log_min_duration_statement = 1000;
ALTER SYSTEM
postgres=# ALTER SYSTEM SET shared_buffers = 'banana';
ERROR:  invalid value for parameter "shared_buffers": "banana"
-- -- Value validated immediately — cannot write bad values
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
postgres=# SHOW work_mem;
 work_mem
----------
 64MB
(1 row)
```

### ALTER SYSTEM RESET and Inspecting auto.conf
**Explanation:** ALTER SYSTEM RESET removes an override and reverts to the value in postgresql.conf. ALTER SYSTEM RESET ALL clears every override in postgresql.auto.conf. You can also view what is in postgresql.auto.conf by querying pg_file_settings and filtering by the auto.conf source.

```sql
postgres=# ALTER SYSTEM RESET work_mem;
ALTER SYSTEM
-- -- work_mem will revert to postgresql.conf value after reload
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
postgres=# -- View what ALTER SYSTEM has written:
postgres=# SELECT sourcefile, name, setting, applied
FROM pg_file_settings
WHERE sourcefile LIKE '%auto%'
ORDER BY name;
                sourcefile                 |           name           | setting | applied
-------------------------------------------+--------------------------+---------+--------
 C:/Program Files/.../postgresql.auto.conf | log_min_duration_statement| 1000   | t
(1 row)
```

### Reload vs Restart — How To
**Explanation:** Let us cover the complete reload versus restart workflow. For sighup-context parameters like work_mem, log settings, and autovacuum settings, a reload is enough. For postmaster-context parameters like shared_buffers, max_connections, and wal_level, you must restart. Here is how to reload and restart on both Windows and Linux.

```sql
-- -- RELOAD (sighup parameters — no downtime):
postgres=# SELECT pg_reload_conf();
-- -- Or from command line:
-- -- Linux:  sudo systemctl reload postgresql
-- -- Linux:  pg_ctl reload -D /var/lib/pgsql/16/data
-- -- Windows: pg_ctl reload -D "C:\Program Files\PostgreSQL\16\data"
-- 
-- -- RESTART (postmaster parameters — brief downtime):
-- -- Linux:  sudo systemctl restart postgresql
-- -- Linux:  pg_ctl restart -D /var/lib/pgsql/16/data
-- -- Windows: Restart PostgreSQL service in Services
-- -- Windows: pg_ctl restart -D "C:\Program Files\PostgreSQL\16\data"
-- 
-- -- After restart, verify:
-- -- SELECT name, setting FROM pg_settings WHERE pending_restart;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Match Order Mistake
Here is a critical beginner trap: match order mistakes. Suppose you want to block user 'intern' from connecting to the production database, but allow all other users. If you write the allow-all rule first and the reject rule second, the intern matches the allow-all rule and gets in — the reject rule never fires. The fix: put specific deny rules BEFORE general allow rules. Always put reject rules at the top of the relevant section.

### Beginner Trap: Connection Refused After Edit
Another beginner trap: you edit pg_hba.conf, reload, and your application still cannot connect. The error says FATAL: no pg_hba.conf entry for host, user, database. This means no line matched. Common causes: the IP address is wrong, you used IPv4 format but the client connects over IPv6, or you forgot that localhost on some systems resolves to the IPv6 address colon colon 1 instead of 127.0.0.1. Always add rules for both IPv4 and IPv6.

```sql
-- Error when connecting:
FATAL:  no pg_hba.conf entry for host "192.168.1.50",
  user "webapp", database "myapp", no encryption

-- Common causes:
-- 1. Wrong CIDR: used /32 instead of /24 for a range
-- 2. IPv4 vs IPv6: client connects as ::1, rule says 127.0.0.1
-- 3. Wrong database name in the rule
-- 4. Forgot to reload after editing

-- Fix: always include BOTH IPv4 and IPv6:
-- host all all 127.0.0.1/32 scram-sha-256
-- host all all ::1/128      scram-sha-256
```

### Beginner Trap: auto.conf Overrides Manual Edits
Here is a beginner trap with ALTER SYSTEM: you edit postgresql.conf directly, but ALTER SYSTEM already has an override in postgresql.auto.conf. Your edit has no effect because auto.conf wins. You spend hours wondering why your change does not apply. Always check postgresql.auto.conf when a manual edit seems to be ignored.

- 1 -- Written to postgresql.auto.conf
- 2 -- Set work_mem = '128MB' in the file
- 3 -- SELECT pg_reload_conf();
- 4 -- Still shows 64MB! auto.conf overrides the manual edit
- 5 -- Removes auto.conf override, then manual edit takes effect


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. pg_hba.conf controls authentication with first-match-wins ordering. Always put deny rules before allow rules, and end with an explicit reject. Use scram-sha-256 for all password authentication. pg_ident.conf maps OS usernames to PostgreSQL roles for peer and ident authentication. ALTER SYSTEM SET is the safest way to change parameters — it validates values and writes to postgresql.auto.conf, which overrides postgresql.conf. Always check pg_file_settings for errors and pg_settings for pending restarts.

- **pg_hba.conf: first matching line wins — ORDER MATTERS**
- **Always deny before allow, end with reject catch-all**
- **scram-sha-256: modern secure auth (never trust in production)**
- **pg_hba_file_rules: validate before reload**
- **pg_ident.conf: maps OS username → PG role for peer/ident**
- **ALTER SYSTEM SET: writes to postgresql.auto.conf (overrides .conf)**
- **ALTER SYSTEM RESET: removes override, reverts to .conf value**
- **Reload (pg_reload_conf): sighup params, no downtime**
- **Restart: postmaster params (shared_buffers, max_connections)**
- **Trap: auto.conf silently overrides manual .conf edits**


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
