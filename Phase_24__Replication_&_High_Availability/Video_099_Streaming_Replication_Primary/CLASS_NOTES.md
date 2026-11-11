# Streaming Replication — Primary Server Setup
**Series:** PostgreSQL Mastery | **Phase:** Phase 24: Replication & High Availability | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we learned what replication is and why it matters. Now we get our hands dirty. In this class, we configure the primary server for streaming replication — every parameter, every file, every line. By the end of this class, your primary server will be ready to stream WAL to any standby that connects.


---

## 2. Core Technical Concepts & Mechanisms

### What We Need to Configure on the Primary
Here is the problem. You have a single PostgreSQL server. If it fails, your application is down. If it gets overloaded with reads, performance drops for everyone. You need a standby server that has an exact copy of your data, receives changes in real time, and can take over if the primary fails. Setting this up requires configuring three things on the primary: the WAL settings in postgresql.conf, the authentication in pg_hba.conf, and a replication user.

- 1. postgresql.conf — WAL Settings -- wal_level, max_wal_senders, wal_keep_size, max_replication_slots
- 2. pg_hba.conf — Authentication -- Allow the standby server to connect for replication
- 3. Replication User -- CREATE ROLE with REPLICATION privilege
- 4. Restart & Verify -- Some parameters require a full restart, not just reload

### pg_hba.conf — Common Mistakes
Important: the 'replication' keyword in pg_hba.conf is NOT a database name. It is a special keyword that means 'this line controls replication connections'. If you write the actual database name instead of 'replication', streaming replication will be denied. This is a common beginner mistake.

| CORRECT | WRONG |
| :--- | :--- |
| host  replication  replicator  10.0.1.0/24  scram-sha-256 | host  mydb  replicator  10.0.1.0/24  scram-sha-256 |
| 'replication' is a KEYWORD | This allows normal connections to 'mydb' |
| It means: allow replication connections | It does NOT allow replication |
| Works for streaming replication | Standby gets: FATAL: no pg_hba.conf entry for replication |
| Works for pg_basebackup | Also wrong: host  all  replicator  ... ('all' ≠ replication) |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Restart vs Reload Parameters
Here are the parameters that need a restart versus those that need only a reload. This distinction is critical — if you change wal_level and only reload, the change is silently ignored until the next restart.

| Requires RESTART | Requires RELOAD only |
| :--- | :--- |
| wal_level | wal_keep_size |
| max_wal_senders | synchronous_standby_names |
| max_replication_slots | synchronous_commit |
| listen_addresses | archive_command |
| shared_buffers | pg_hba.conf changes |
| archive_mode | max_slot_wal_keep_size |

### Primary Server Setup Checklist
Here is your complete setup checklist for the primary server. Follow this order every time.

- 1. Verify wal_level = replica -- SHOW wal_level; (PG 16 default is already 'replica')
- 2. Set max_wal_senders = 10 -- ALTER SYSTEM SET max_wal_senders = 10;
- 3. Set wal_keep_size = 1GB+ -- ALTER SYSTEM SET wal_keep_size = '1GB';
- 4. Set max_replication_slots = 10 -- ALTER SYSTEM SET max_replication_slots = 10;
- 5. Edit pg_hba.conf -- host  replication  replicator  <standby_ip>/32  scram-sha-256
- 6. Create replication user -- CREATE ROLE replicator REPLICATION LOGIN PASSWORD '...';
- 7. Restart PostgreSQL -- sudo systemctl restart postgresql
- 8. Verify all settings -- SHOW wal_level; SHOW max_wal_senders; check pending_restart


---

## 3. Hands-On Commands & psql Output

### Step 1: Check wal_level
**Explanation:** Let us start with the most important parameter: wal_level. This controls how much information PostgreSQL writes to the WAL. For streaming replication, we need at least 'replica'. Good news — PostgreSQL 16 already defaults to 'replica', so you may not need to change this. But always verify it.

```sql
postgres=# SHOW wal_level;
 wal_level
postgres=# -----------
 replica
(1 row)
postgres=# -- If it shows 'minimal', change it:
postgres=# -- ALTER SYSTEM SET wal_level = 'replica';
postgres=# -- Then restart PostgreSQL (reload is NOT enough)
postgres=# -- For logical replication later, set 'logical':
postgres=# -- ALTER SYSTEM SET wal_level = 'logical';
postgres=# -- 'logical' includes everything 'replica' does
```

### Step 2: Configure max_wal_senders
**Explanation:** Next, max_wal_senders. This limits how many standby servers can connect simultaneously. Each standby uses one WAL sender process. The default is 10, which is fine for most setups. But remember — pg_basebackup also uses a WAL sender slot during backup, so leave some headroom.

```sql
postgres=# SHOW max_wal_senders;
 max_wal_senders
postgres=# -----------------
 10
(1 row)
postgres=# -- Each standby uses 1 slot
postgres=# -- pg_basebackup uses 1 slot (or 2 with --wal-method=stream)
postgres=# -- Formula: number_of_standbys + 2 (headroom)
postgres=# -- If you need more:
postgres=# -- ALTER SYSTEM SET max_wal_senders = 10;
postgres=# -- Requires restart
```

### Step 3: Configure wal_keep_size
**Explanation:** Now, wal_keep_size. This tells PostgreSQL to keep this much WAL on disk even after it has been checkpointed. If a standby disconnects briefly, it can reconnect and catch up using the retained WAL. Without this, the primary might recycle WAL segments that the standby still needs. Set this to at least 1 gigabyte for production.

```sql
postgres=# SHOW wal_keep_size;
 wal_keep_size
postgres=# ---------------
 0
(1 row)
postgres=# -- Default is 0 (no extra retention)
postgres=# -- Set to at least 1GB for replication:
postgres=# ALTER SYSTEM SET wal_keep_size = '1GB';
postgres=# ALTER SYSTEM
postgres=# -- This keeps ~64 WAL segments (16MB each)
postgres=# -- If standby is offline for a while, this gives it
postgres=# -- a window to reconnect without needing pg_basebackup
postgres=# -- For busy servers, consider 2GB-4GB
postgres=# -- Requires restart to take effect
```

### Step 4: Configure max_replication_slots
**Explanation:** max_replication_slots controls how many replication slots can exist. Replication slots are a more reliable way to prevent WAL deletion than wal_keep_size alone — they track exactly what each standby has received. The default is 10, which is usually sufficient.

```sql
postgres=# SHOW max_replication_slots;
 max_replication_slots
postgres=# -----------------------
 10
(1 row)
postgres=# -- Default is 10 — usually enough
postgres=# -- Each standby can use one physical slot
postgres=# -- Logical replication also uses slots
postgres=# -- Formula: physical_standbys + logical_subscriptions + 2
postgres=# -- If you need more:
postgres=# -- ALTER SYSTEM SET max_replication_slots = 10;
postgres=# -- Requires restart
```

### Step 5: Configure pg_hba.conf
**Explanation:** Now the critical step — pg_hba.conf. This file controls who can connect to PostgreSQL and how they authenticate. We need to add a line that allows the standby server to connect specifically for replication. The connection type is 'host', the database is 'replication' — a special keyword — and we specify the standby's IP address.

```sql
postgres=# -- Find your pg_hba.conf location:
postgres=# SHOW hba_file;
              hba_file
postgres=# ---------------------------------
 /etc/postgresql/16/main/pg_hba.conf
(1 row)
postgres=# -- Add this line to pg_hba.conf:
postgres=# -- TYPE   DATABASE      USER          ADDRESS          METHOD
postgres=# -- host   replication   replicator    10.0.1.0/24      scram-sha-256
postgres=# -- Explanation:
postgres=# -- host          = TCP/IP connection
postgres=# -- replication   = special keyword (not a database name)
postgres=# -- replicator    = the role we will create next
postgres=# -- 10.0.1.0/24   = allow from this subnet
postgres=# -- scram-sha-256 = secure password authentication
```

### Step 6: Create Replication User
**Explanation:** Now we create the replication user. This role needs the REPLICATION privilege and LOGIN. Do not use the postgres superuser for replication — principle of least privilege. The replicator role only needs to stream WAL, nothing more.

```sql
postgres=# CREATE ROLE replicator
postgres=# WITH REPLICATION LOGIN PASSWORD 'SecurePass123!';
postgres=# CREATE ROLE
postgres=# -- Verify the role:
postgres=# SELECT rolname, rolreplication, rolcanlogin
postgres-# FROM pg_roles WHERE rolname = 'replicator';
  rolname    | rolreplication | rolcanlogin
postgres=# -------------+----------------+-------------
 replicator  | t              | t
(1 row)
postgres=# -- REPLICATION = can stream WAL
postgres=# -- LOGIN = can connect to PostgreSQL
postgres=# -- No SUPERUSER, no CREATEDB, no CREATEROLE
postgres=# -- Minimum privileges for replication
```

### Step 7: Restart PostgreSQL
**Explanation:** With all changes made, we need to restart PostgreSQL. A reload is not enough for wal_level, max_wal_senders, and max_replication_slots — these require a full restart. The pg_hba.conf change only needs a reload, but since we are restarting anyway, it all takes effect at once.

```sql
# Check which parameters need restart:
psql -U postgres -c "
postgres=# SELECT name, setting, pending_restart
postgres-# FROM pg_settings
postgres-# WHERE name IN ('wal_level','max_wal_senders',
    'wal_keep_size','max_replication_slots')
postgres-# ORDER BY name;"
         name          | setting | pending_restart
postgres=# -----------------------+---------+-----------------
 max_replication_slots | 10      | f
 max_wal_senders       | 10      | f
 wal_keep_size         | 1024    | t
 wal_level             | replica | f
# Restart PostgreSQL:
sudo systemctl restart postgresql
# Verify it started:
sudo systemctl status postgresql
● postgresql.service - PostgreSQL RDBMS
   Active: active (running)
```

### Step 8: Verify Configuration
**Explanation:** After restart, verify everything is set correctly. Run these queries to confirm your primary is ready for replication.

```sql
postgres=# SHOW wal_level;
 wal_level
postgres=# -----------
 replica
postgres=# SHOW max_wal_senders;
 max_wal_senders
postgres=# -----------------
 10
postgres=# SHOW wal_keep_size;
 wal_keep_size
postgres=# ---------------
 1GB
postgres=# SHOW max_replication_slots;
 max_replication_slots
postgres=# -----------------------
 10
postgres=# -- Verify replication user can connect:
postgres=# -- From standby machine (or local test):
postgres=# -- psql -h primary_ip -U replicator -d postgres
postgres=# -- Should prompt for password and connect
```

### Optional: Create Replication Slot
**Explanation:** Optionally, create a physical replication slot on the primary before the standby connects. This guarantees WAL retention for that specific standby. Without a slot, you rely on wal_keep_size alone.

```sql
postgres=# -- Create a physical replication slot:
postgres=# SELECT pg_create_physical_replication_slot('standby1_slot');
 pg_create_physical_replication_slot
postgres=# -------------------------------------
 (standby1_slot,)
(1 row)
postgres=# -- Verify the slot:
postgres=# SELECT slot_name, slot_type, active
postgres-# FROM pg_replication_slots;
   slot_name    | slot_type | active
postgres=# -----------------+-----------+--------
 standby1_slot   | physical  | f
(1 row)
postgres=# -- active = false (no standby connected yet)
postgres=# -- Once the standby connects using this slot,
postgres=# -- active becomes true
```

### Beginner Trap: Reload vs Restart
**Explanation:** Let me show you a common beginner trap. You set wal_level to replica using ALTER SYSTEM and then run SELECT pg_reload_conf. PostgreSQL accepts the reload without error. You run SHOW wal_level and it STILL shows the old value. No error, no warning. The change is pending but needs a full restart. Always check pending_restart in pg_settings after changes.

```sql
postgres=# -- You changed wal_level to 'logical':
postgres=# ALTER SYSTEM SET wal_level = 'logical';
postgres=# ALTER SYSTEM
postgres=# -- You reload (WRONG — this is not enough):
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
postgres=# ----------------
 t
postgres=# -- Check — still 'replica'!
postgres=# SHOW wal_level;
 wal_level
postgres=# -----------
 replica
postgres=# -- No error! Silent failure!
postgres=# -- Check pending_restart:
postgres=# SELECT name, setting, pending_restart
postgres-# FROM pg_settings WHERE name = 'wal_level';
   name    | setting | pending_restart
postgres=# -----------+---------+-----------------
 wal_level | replica | t
postgres=# -- pending_restart = t means: RESTART required!
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — Complete Primary Server — postgresql.conf
Let us see all the WAL and replication parameters together in one view. Here is the complete postgresql.conf configuration block for the primary server. Crucially, parameters marked RESTART require stopping and restarting PostgreSQL, whereas parameters marked RELOAD take effect instantly with SELECT pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `wal_level` | `replica` | **`[RESTART]`** (Postmaster Restart) | Required for streaming (Default: replica) |
| `max_wal_senders` | `10` | **`[RESTART]`** (Postmaster Restart) | Max standby streams (Default: 10) |
| `wal_keep_size` | `1GB` | `[RELOAD]` (Live Reload `SIGHUP`) | Retain WAL segments in pg_wal (Default: 0) |
| `max_replication_slots` | `10` | **`[RESTART]`** (Postmaster Restart) | Physical & logical slots (Default: 10) |
| `listen_addresses` | `'*'` | **`[RESTART]`** (Postmaster Restart) | Listen on all IP interfaces (Default: 'localhost') |
| `hot_standby` | `on` | **`[RESTART]`** (Postmaster Restart) | Allow read queries on standby (Default: on) |
| `archive_mode` | `on` | **`[RESTART]`** (Postmaster Restart) | Enable WAL archiving for PITR (Default: off) |
| `archive_command` | `'cp %p /archive/%f'` | `[RELOAD]` (Live Reload `SIGHUP`) | Copy WAL command |



---

## 5. Common Beginner Traps & How to Fix Them

### pg_hba.conf — Common Mistakes
Important: the 'replication' keyword in pg_hba.conf is NOT a database name. It is a special keyword that means 'this line controls replication connections'. If you write the actual database name instead of 'replication', streaming replication will be denied. This is a common beginner mistake.

### Beginner Trap: Reload vs Restart
Let me show you a common beginner trap. You set wal_level to replica using ALTER SYSTEM and then run SELECT pg_reload_conf. PostgreSQL accepts the reload without error. You run SHOW wal_level and it STILL shows the old value. No error, no warning. The change is pending but needs a full restart. Always check pending_restart in pg_settings after changes.

```sql
-- You changed wal_level to 'logical':
postgres=# ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM
-- You reload (WRONG — this is not enough):
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
-- Check — still 'replica'!
postgres=# SHOW wal_level;
 wal_level
-----------
 replica
-- No error! Silent failure!
-- Check pending_restart:
postgres=# SELECT name, setting, pending_restart
FROM pg_settings WHERE name = 'wal_level';
   name    | setting | pending_restart
-----------+---------+-----------------
 wal_level | replica | t
-- pending_restart = t means: RESTART required!
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. To prepare the primary for streaming replication, set wal_level to replica, configure max_wal_senders and wal_keep_size, add a replication line to pg_hba.conf using the 'replication' keyword, create a replication user with the REPLICATION privilege, and restart PostgreSQL. Always check pending_restart after ALTER SYSTEM — reload is not enough for WAL parameters. In the next class, we set up the standby server — pg_basebackup, standby.signal, and the first data sync.

- **wal_level = replica (PG 16 default, verify it)**
- **max_wal_senders = 10 (standbys + basebackup headroom)**
- **wal_keep_size = 1GB+ (WAL retention for reconnection)**
- **max_replication_slots = 10 (one per standby)**
- **pg_hba.conf: host replication replicator <IP> scram-sha-256**
- **'replication' is a keyword in pg_hba.conf, NOT a database name**
- **CREATE ROLE replicator REPLICATION LOGIN PASSWORD '...'**
- **ALTER SYSTEM changes need RESTART, not just RELOAD**
- **Check pg_settings.pending_restart after changes**
- **Optional: create physical replication slot for each standby**
- **Next: Streaming Replication — Standby Server Setup**


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
