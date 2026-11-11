# Major Version Upgrades with Logical Replication
**Series:** PostgreSQL Mastery | **Phase:** Phase 28: Upgrade & Migration | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we used pg_upgrade to do major version upgrades. pg_upgrade is fast, especially in link mode, but it still requires stopping the old server — which means downtime. For some systems, even a few minutes of downtime is unacceptable. Think of banking systems, e-commerce during peak hours, or healthcare databases. Today we learn how to use logical replication to upgrade PostgreSQL with zero downtime. The old server keeps running and serving traffic while the new server catches up. When they are in sync, you switch traffic in seconds. Let us learn how.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand pg_upgrade from the previous class. You should also know the basics of logical replication from Phase 23 — publications, subscriptions, and how logical decoding works. Recap — pg_upgrade migrates the catalog while reusing data files. It is fast but requires stopping the old server. Logical replication keeps both servers running during the migration.

- Prerequisite: pg_upgrade (previous class)
- Prerequisite: Logical replication basics (Phase 23)
- Prerequisite: Publications and subscriptions
- Recap: pg_upgrade requires downtime (both clusters stopped)
- Now: Zero-downtime upgrade using logical replication

### Zero-Downtime Upgrade Architecture
Here is the architecture. The old server running PostgreSQL 15 is on the left — it is your current production server handling all traffic. The new server running PostgreSQL 16 is on the right. A logical replication channel connects them. The old server publishes changes through a replication slot. The new server subscribes and applies those changes. Your application currently points to the old server. During cutover, you point it to the new server instead. The old server stays running until you confirm everything works, then you decommission it.

```
[Application]
[Old Server
PG 15 (Publisher)]
[New Server
PG 16 (Subscriber)]
[Replication Slot
(logical)]
```

### Support This Free Course
If you are learning from this course, here is how to support it. Like this video so more people find it. Share it with someone learning PostgreSQL. Subscribe and hit the bell icon so you never miss a class. Download today's class materials from the link in the description. And if this free course is helping you, consider supporting it through the donation link in the description. Now let us do the cutover.

- Like this video — helps others discover PostgreSQL Mastery
- Share with someone learning PostgreSQL
- Subscribe + bell icon for new classes
- Download class materials (link in description)
- Support this free course: donation link in description

### Logical Replication Upgrade — Limitations
There are limitations to the logical replication upgrade approach. It only replicates DML — INSERT, UPDATE, DELETE. DDL changes like CREATE TABLE or ALTER TABLE are not replicated. If someone adds a column on the old server during the migration, you need to add it manually on the new server too. Large objects and TRUNCATE may need special handling depending on the version. And every table must have a primary key or REPLICA IDENTITY for UPDATE and DELETE operations to work.

| What IS Replicated | What IS NOT Replicated |
| :--- | :--- |
| INSERT, UPDATE, DELETE | DDL (CREATE, ALTER, DROP TABLE) |
| All table data | Sequences (must sync manually) |
| Changes in real-time after initial sync | Large Objects (special handling) |
| Multiple databases (separate pub/sub each) | Roles and permissions (pg_dumpall --globals-only) |
|  | Tables without PRIMARY KEY (need REPLICA IDENTITY) |

### pg_upgrade vs Logical Replication Upgrade
When should you use logical replication for upgrades versus pg_upgrade? Use pg_upgrade when you can tolerate a few minutes of downtime — it is simpler and handles everything including sequences, roles, and DDL automatically. Use logical replication when zero downtime is required, when you need to test the new version with real production traffic before fully committing, or when you want to upgrade and reorganize the schema at the same time.

| pg_upgrade | Logical Replication |
| :--- | :--- |
| Simpler process (one command) | More complex setup |
| Handles everything automatically | Sequences, DDL, roles need manual handling |
| Requires downtime (minutes) | Zero downtime (cutover = seconds) |
| Link mode: seconds for any DB size | Can test new version with live data |
| Best for: most production systems | Best for: 24/7 systems, critical uptime |

### Rollback Strategy
What if the cutover goes wrong and you need to rollback? The beauty of the logical replication approach is that the old server is still running and has all the data up to the cutover point. If you discover a problem on the new server within the first few minutes, simply point your application back to the old server. Any data written to the new server after cutover would be lost, so make sure to test thoroughly before decommissioning the old server. Keep the old server running for at least 24 hours after cutover as a safety net.

- Old server stays running after cutover — it is your safety net
- If problems found on new server: point app back to old server
- Data written to new server post-cutover would be lost
- Keep old server running 24+ hours after successful cutover
- For critical systems: set up reverse replication (new → old)
- Only decommission old server after full verification
- Document the rollback procedure BEFORE starting the upgrade

### Practice Exercises
Here are your practice exercises. One — set up logical replication between two PostgreSQL versions on a test server. Create publication and subscription, verify initial sync completes. Two — insert, update, and delete rows on the old server and verify they appear on the new server. Three — practice the cutover — stop writes, sync sequences, switch traffic. Four — test what happens when you forget to sync sequences by inserting data before setval. Five — practice the full zero-downtime upgrade workflow from start to finish.

- 1. Set up publication/subscription between PG 15 and 16
- 2. Insert/update/delete on old server — verify on new server
- 3. Practice the cutover: stop writes, sync sequences, switch
- 4. Test: insert before setval — observe duplicate key error
- 5. Full zero-downtime upgrade workflow start to finish


---

## 3. Hands-On Commands & psql Output

### Step 1: Prepare Old Server (PG 15)
**Explanation:** Step one — prepare the old server. The old server needs logical replication enabled. Set wal_level to logical in postgresql.conf. This requires a restart. Also set max_replication_slots and max_wal_senders to at least the number of databases you will replicate. Create a replication user with the REPLICATION privilege if you do not already have one.

```sql
-- Check current wal_level:
postgres=# SHOW wal_level;
 wal_level
-----------
 replica      <-- Need 'logical'

-- Change to logical:
postgres=# ALTER SYSTEM SET wal_level = logical;
ALTER SYSTEM
postgres=# ALTER SYSTEM SET max_replication_slots = 10;
ALTER SYSTEM
postgres=# ALTER SYSTEM SET max_wal_senders = 10;
ALTER SYSTEM

-- Restart required for wal_level:
$ sudo systemctl restart postgresql-15

-- Create replication user:
postgres=# CREATE ROLE repl_upgrade WITH LOGIN REPLICATION PASSWORD 'repl_pass_2026';
CREATE ROLE
postgres=# GRANT SELECT ON ALL TABLES IN SCHEMA public TO repl_upgrade;
GRANT
```

### Step 2: Prepare New Server (PG 16)
**Explanation:** Step two — install and prepare the new server. Install PostgreSQL 16 on the target server. Initialize the cluster. Then export the schema from the old server and import it into the new one. Use pg_dump with the schema-only flag — this copies all tables, indexes, constraints, views, functions, and extensions without any data. The data will come through logical replication.

```sql
-- Install PG 16 on new server:
$ sudo apt install postgresql-16

-- Export schema from old server (PG 15):
$ pg_dump -h old-server -U postgres --schema-only app_db > schema.sql

-- Import schema into new server (PG 16):
$ psql -U postgres -d app_db -f schema.sql

-- Also export and import global objects (roles, tablespaces):
$ pg_dumpall -h old-server -U postgres --globals-only > globals.sql
$ psql -U postgres -f globals.sql

-- Verify schema is present but empty:
postgres=# \dt
        List of relations
 Schema |  Name   | Type  |  Owner
--------+---------+-------+----------
 public | orders  | table | postgres
 public | users   | table | postgres
postgres=# SELECT count(*) FROM orders;
 count
-------
     0     <-- Empty, data comes via replication
```

### Step 3: Create Publication (Old Server)
**Explanation:** Step three — create the publication on the old server. A publication defines which tables will be replicated. Use FOR ALL TABLES to replicate everything, or list specific tables. Every table in the publication must have a primary key or REPLICA IDENTITY — logical replication needs a way to identify rows for UPDATE and DELETE operations.

```sql
-- On old server (PG 15):

-- Option A: publish ALL tables:
postgres=# CREATE PUBLICATION upgrade_pub FOR ALL TABLES;
CREATE PUBLICATION

-- Option B: publish specific tables:
-- CREATE PUBLICATION upgrade_pub FOR TABLE users, orders, products;

-- Check all tables have primary keys:
postgres=# SELECT c.relname FROM pg_class c
postgres-# JOIN pg_namespace n ON c.relnamespace = n.oid
postgres-# WHERE c.relkind = 'r' AND n.nspname = 'public'
postgres-# AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisprimary);
 relname
---------
(0 rows)    <-- Good: all tables have primary keys

-- Add pg_hba.conf rule for replication from new server:
-- hostssl all repl_upgrade 10.0.1.20/32 scram-sha-256
postgres=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
```

### Handling Tables Without Primary Keys
**Explanation:** Before creating the subscription, handle any tables without primary keys. Logical replication needs a way to identify rows for UPDATE and DELETE operations. If a table has a primary key, it uses that automatically. If not, you have two options. Set REPLICA IDENTITY to FULL — this compares all columns to find the row, which works but is slower. Or better, add a proper primary key to the table. Check all tables now before starting replication.

```sql
-- Find tables WITHOUT a primary key:
postgres=# SELECT c.relname FROM pg_class c
postgres-# JOIN pg_namespace n ON c.relnamespace = n.oid
postgres-# WHERE c.relkind = 'r' AND n.nspname = 'public'
postgres-# AND NOT EXISTS (SELECT 1 FROM pg_index i WHERE i.indrelid = c.oid AND i.indisprimary);
 relname
---------
 audit_log

-- Option A: Add a primary key (recommended):
postgres=# ALTER TABLE audit_log ADD COLUMN id BIGSERIAL PRIMARY KEY;
ALTER TABLE

-- Option B: Use REPLICA IDENTITY FULL (slower):
-- ALTER TABLE audit_log REPLICA IDENTITY FULL;

-- Check REPLICA IDENTITY for all tables:
postgres=# SELECT relname, CASE relreplident WHEN 'd' THEN 'default (PK)'
postgres-# WHEN 'f' THEN 'full' WHEN 'n' THEN 'nothing' END AS replica_id
postgres-# FROM pg_class WHERE relkind = 'r' AND relnamespace = 'public'::regnamespace;
  relname   | replica_id
-----------+------------
 orders    | default (PK)
 users     | default (PK)
 audit_log | default (PK)
```

### Step 4: Create Subscription (New Server)
**Explanation:** Step four — create the subscription on the new server. The subscription connects to the old server's publication and starts replicating. First, it performs an initial table sync — copying all existing data row by row. Then it switches to streaming mode, applying changes as they happen on the old server. The copy_data option must be true for the initial sync.

```sql
-- On new server (PG 16):

postgres=# CREATE SUBSCRIPTION upgrade_sub
postgres-# CONNECTION 'host=old-server dbname=app_db user=repl_upgrade password=repl_pass_2026'
postgres-# PUBLICATION upgrade_pub
postgres-# WITH (copy_data = true);
NOTICE:  created replication slot "upgrade_sub" on publisher
CREATE SUBSCRIPTION

-- Monitor initial sync progress:
postgres=# SELECT srsubid::regsubscription, srrelid::regclass, srsubstate
postgres-# FROM pg_subscription_rel;
   srsubid   | srrelid | srsubstate
-------------+---------+------------
 upgrade_sub | orders  | d          <-- d = data copy in progress
 upgrade_sub | users   | r          <-- r = ready (sync done)
```

### Step 5: Monitor Replication Lag
**Explanation:** Step five — monitor replication lag until it reaches zero. On the old server, check the replication slot's lag. On the new server, check the subscription state. When all tables show state r for ready and the lag is zero, the new server has caught up completely. At this point, both servers have identical data and ongoing changes are being applied in near real-time.

```sql
-- On OLD server — check replication slot lag:
postgres=# SELECT slot_name, active,
postgres-# pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS lag
postgres-# FROM pg_replication_slots WHERE slot_name = 'upgrade_sub';
  slot_name  | active |  lag
-------------+--------+-------
 upgrade_sub | t      | 0 bytes    <-- Caught up!

-- On NEW server — check all tables are ready:
postgres=# SELECT srrelid::regclass, srsubstate FROM pg_subscription_rel;
 srrelid | srsubstate
---------+------------
 orders  | r
 users   | r
-- All 'r' (ready) = sync complete

-- Verify row counts match:
-- Old: SELECT count(*) FROM orders;  => 1250000
-- New: SELECT count(*) FROM orders;  => 1250000
```

### Step 6: The Cutover (Zero-Downtime Switch)
**Explanation:** Step six — the cutover. This is the critical moment. First, stop the application from writing to the old server — put it in maintenance mode, close the connection pool, or point it to a read-only standby temporarily. Wait for the last changes to replicate to the new server — this takes seconds. Then enable sequences on the new server because logical replication does not replicate sequence values. Update your application connection string to point to the new server. Start accepting traffic on the new server. Total downtime: seconds, not minutes.

```sql
-- 1. Stop writes to old server (briefly):
-- Pause app, drain connections, or set to read-only

-- 2. Wait for replication to catch up (seconds):
-- Check lag = 0 bytes on old server

-- 3. Sync sequences on new server:
postgres=# SELECT setval('orders_id_seq',
postgres-# (SELECT max(id) FROM orders));
 setval
--------
 1250000

-- Do this for EVERY sequence:
-- SELECT setval('users_id_seq', (SELECT max(id) FROM users));

-- 4. Drop subscription on new server:
postgres=# ALTER SUBSCRIPTION upgrade_sub DISABLE;
ALTER SUBSCRIPTION
postgres=# DROP SUBSCRIPTION upgrade_sub;
DROP SUBSCRIPTION

-- 5. Point application to new server (PG 16)
-- Update connection string / DNS / load balancer
```

### Syncing Sequences After Cutover
**Explanation:** An important detail — sequences. Logical replication does not replicate sequence values. After the cutover, you must manually set each sequence to the correct value on the new server. Use setval with the max value from each corresponding table. If you forget this step, new inserts will start from 1 and collide with existing primary keys. Here is a query that generates the setval commands for all sequences automatically.

```sql
-- Generate setval commands for ALL sequences:
SELECT format(
  'SELECT setval(%L, COALESCE((SELECT max(%I) FROM %I.%I), 1));',
  seq.seqname,
  col.attname,
  tab_ns.nspname,
  tab.relname
)
FROM pg_class seq
JOIN pg_namespace seq_ns ON seq.relnamespace = seq_ns.oid
JOIN pg_depend d ON d.objid = seq.oid
JOIN pg_class tab ON d.refobjid = tab.oid
JOIN pg_namespace tab_ns ON tab.relnamespace = tab_ns.oid
JOIN pg_attribute col ON col.attrelid = tab.oid
  AND col.attnum = d.refobjsubid
WHERE seq.relkind = 'S'
  AND d.deptype = 'a'
ORDER BY seq.relname;

-- Output:
-- SELECT setval('orders_id_seq', COALESCE((SELECT max(id) FROM public.orders), 1));
-- SELECT setval('users_id_seq', COALESCE((SELECT max(id) FROM public.users), 1));
```

### Multi-Database Upgrade
**Explanation:** If you have multiple databases on the same server, you need a separate publication and subscription for each database. Logical replication operates at the database level — one publication per database, one subscription per database. Set them all up, let them all sync, and cut over all databases at the same time during the switch.

```sql
-- For each database, repeat the pub/sub setup:

-- Database 1: app_db
-- Old server:
-- CREATE PUBLICATION upgrade_pub_app FOR ALL TABLES;
-- New server:
-- CREATE SUBSCRIPTION upgrade_sub_app CONNECTION '...' PUBLICATION upgrade_pub_app;

-- Database 2: analytics_db
-- Old server:
-- CREATE PUBLICATION upgrade_pub_analytics FOR ALL TABLES;
-- New server:
-- CREATE SUBSCRIPTION upgrade_sub_analytics CONNECTION '...' PUBLICATION upgrade_pub_analytics;

-- Monitor all subscriptions:
postgres=# SELECT subname, subenabled FROM pg_subscription;
        subname         | subenabled
------------------------+------------
 upgrade_sub_app        | t
 upgrade_sub_analytics  | t
```

### Beginner Traps — Logical Replication Upgrade
**Explanation:** Beginner trap number one — forgetting to sync sequences. Your application inserts a row, gets id 1, and crashes because id 1 already exists. Always sync all sequences before sending traffic to the new server. Trap two — schema changes during migration. Someone runs ALTER TABLE ADD COLUMN on the old server. The new server does not have that column. Replication breaks. Freeze schema changes during the migration window, or apply them to both servers. Trap three — tables without primary keys. Logical replication cannot do UPDATE or DELETE without a way to identify rows. Add primary keys or set REPLICA IDENTITY FULL before starting.

```sql
-- Trap 1: Forgot to sync sequences
INSERT INTO orders (total) VALUES (99.99);
ERROR:  duplicate key value violates unique constraint "orders_pkey"
DETAIL: Key (id)=(1) already exists.
-- Fix: setval() for every sequence BEFORE cutover

-- Trap 2: Schema change during migration
-- Old server: ALTER TABLE orders ADD COLUMN status TEXT;
-- New server: column missing — replication error
-- Fix: freeze DDL changes during migration window

-- Trap 3: Table without primary key
-- UPDATE/DELETE fails with:
ERROR: logical replication target relation "logs" has neither
  REPLICA IDENTITY index nor PRIMARY KEY
-- Fix: ALTER TABLE logs ADD PRIMARY KEY (id);
-- Or:  ALTER TABLE logs REPLICA IDENTITY FULL;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Logical Replication Upgrade
Beginner trap number one — forgetting to sync sequences. Your application inserts a row, gets id 1, and crashes because id 1 already exists. Always sync all sequences before sending traffic to the new server. Trap two — schema changes during migration. Someone runs ALTER TABLE ADD COLUMN on the old server. The new server does not have that column. Replication breaks. Freeze schema changes during the migration window, or apply them to both servers. Trap three — tables without primary keys. Logical replication cannot do UPDATE or DELETE without a way to identify rows. Add primary keys or set REPLICA IDENTITY FULL before starting.

```sql
-- Trap 1: Forgot to sync sequences
INSERT INTO orders (total) VALUES (99.99);
ERROR:  duplicate key value violates unique constraint "orders_pkey"
DETAIL: Key (id)=(1) already exists.
-- Fix: setval() for every sequence BEFORE cutover

-- Trap 2: Schema change during migration
-- Old server: ALTER TABLE orders ADD COLUMN status TEXT;
-- New server: column missing — replication error
-- Fix: freeze DDL changes during migration window

-- Trap 3: Table without primary key
-- UPDATE/DELETE fails with:
ERROR: logical replication target relation "logs" has neither
  REPLICA IDENTITY index nor PRIMARY KEY
-- Fix: ALTER TABLE logs ADD PRIMARY KEY (id);
-- Or:  ALTER TABLE logs REPLICA IDENTITY FULL;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. Logical replication enables zero-downtime major version upgrades. Set up a publication on the old server and a subscription on the new server. The initial sync copies all data, then ongoing changes stream in real-time. Monitor replication lag until it reaches zero. Cutover means stopping writes briefly, syncing sequences, and switching the connection string. Key limitations: DDL is not replicated, sequences must be synced manually, and all tables need primary keys. Use this approach when downtime is not acceptable.

- **Logical replication = zero-downtime major version upgrade**
- **Publication on old, Subscription on new**
- **Initial sync copies data, then streams ongoing changes**
- **Monitor lag until 0 bytes, then cutover**
- **Cutover: stop writes, sync sequences, switch connection**
- **DDL not replicated — freeze schema changes during migration**
- **All tables need PRIMARY KEY or REPLICA IDENTITY**
- **Simpler: pg_upgrade; Zero-downtime: logical replication**


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
