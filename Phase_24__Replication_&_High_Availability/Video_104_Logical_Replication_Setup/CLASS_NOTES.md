# Logical Replication Setup — Publications & Subscriptions
**Series:** PostgreSQL Mastery | **Phase:** Phase 24: Replication & High Availability | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Until now, we used streaming replication — it copies the entire database cluster as a byte-for-byte replica. But what if you want to replicate just one table? Or replicate between different PostgreSQL versions? Or let the subscriber have its own local tables and even accept writes? That is what logical replication does. In this class, we set up publications and subscriptions from scratch.


---

## 2. Core Technical Concepts & Mechanisms

### Streaming vs Logical — Key Differences
Logical replication works at the SQL level, not the WAL byte level. The publisher decodes WAL into row-level changes — INSERT, UPDATE, DELETE — and sends them to the subscriber. The subscriber applies them as regular SQL operations. This means the subscriber can have different indexes, different additional tables, and even different PostgreSQL versions.

| Streaming (Physical) | Logical |
| :--- | :--- |
| Copies WAL bytes (binary) | Copies row-level changes (SQL) |
| Entire cluster replicated | Selective: specific tables |
| Standby is read-only | Subscriber is read-write |
| Same PG version required | Different PG versions OK |
| Identical data directory | Subscriber has own tables/indexes |
| Used for: HA, failover | Used for: migrations, CDC, selective sync |

### Logical Replication Architecture
The architecture has three components. The publisher creates a publication — a set of tables whose changes should be shared. The subscriber creates a subscription that connects to the publisher and receives changes. Between them, a logical replication slot on the publisher tracks what has been sent.

```
[Publisher Server
(source of data)]
[Publication
(orders, customers)]
[Logical WAL Sender
(decodes + streams)]
[Subscriber Server
(receives changes)]
[Subscription
(connects to publisher)]
[Apply Worker
(applies as SQL)]
```

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### What Logical Replication Does NOT Replicate
Here is what logical replication does NOT replicate. This is critical to understand. Schema changes, sequences, large objects, and DDL statements are not replicated. If you add a column on the publisher, you must add it on the subscriber manually.

| Not Replicated | Why It Matters |
| :--- | :--- |
| DDL (CREATE/ALTER/DROP) | Must run schema changes on subscriber manually |
| Sequences (nextval) | Subscriber sequences may fall behind — reset after failover |
| Large objects (lo_*) | Use TOAST-based columns instead |
| TRUNCATE (default) | Add WITH (publish = 'insert, update, delete, truncate') |
| Schema/Database creation | Create databases/schemas on subscriber first |
| Roles and permissions | Create roles on subscriber separately |

### Common Logical Replication Errors
Here are the common errors you will encounter with logical replication and how to fix them.

| Error | Cause & Fix |
| :--- | :--- |
| cannot update table: no replica identity | Table needs PRIMARY KEY or ALTER TABLE ... REPLICA IDENTITY FULL |
| relation does not exist on subscriber | Create matching table on subscriber BEFORE subscribing |
| column mismatch | Subscriber table must have all published columns with matching types |
| duplicate key violation on subscriber | Initial sync + existing data conflict — TRUNCATE subscriber first |
| slot already exists | Drop old slot: pg_drop_replication_slot('name') |
| permission denied for table | GRANT SELECT ON published tables TO replication user |

### Subscriber is Read-Write — But Be Careful
Subscriber can also write to replicated tables — unlike streaming replication standbys. But be careful: if both sides insert with conflicting primary keys, replication breaks with a duplicate key error.

| What Works | What Breaks |
| :--- | :--- |
| INSERT into local-only tables | INSERT with same PK as publisher → conflict |
| INSERT into replicated tables (if no PK conflict) | UPDATE/DELETE publisher's rows → no conflict, but confusing |
| CREATE additional indexes | Subscriber changes are NOT sent back to publisher |
| CREATE local-only tables | Bidirectional replication needs extra setup |
| Run analytics queries on replicated data | Sequence values may collide without coordination |

### Use Case: Zero-Downtime PG Version Upgrade
Here is a practical use case: major version upgrade. You set up logical replication from old PG to new PG, let it sync, then switch your application to the new server. Zero-downtime migration.

- 1. Install new PG version alongside old -- e.g., PG 15 (publisher) → PG 16 (subscriber)
- 2. Create matching schema on new PG -- pg_dump --schema-only from old → restore on new
- 3. Set up logical replication -- CREATE PUBLICATION on old, CREATE SUBSCRIPTION on new
- 4. Wait for initial sync to complete -- Monitor pg_subscription_rel for srsubstate = 'r' (ready)
- 5. Switch application to new server -- Stop writes on old, verify lag = 0, update connection string
- 6. Drop subscription and publication -- Clean up old replication setup


---

## 3. Hands-On Commands & psql Output

### Step 1: Set wal_level = logical (Publisher)
**Explanation:** First requirement: wal_level must be set to 'logical' on the publisher. This is higher than 'replica' — it includes row-level change information that the logical decoder needs. If your wal_level is already 'replica' from streaming replication setup, you need to change it and restart.

```sql
postgres=# SHOW wal_level;
 wal_level
postgres=# -----------
 replica
postgres=# -- Change to logical:
postgres=# ALTER SYSTEM SET wal_level = 'logical';
postgres=# ALTER SYSTEM
postgres=# -- Restart required (reload is NOT enough):
postgres=# -- sudo systemctl restart postgresql
postgres=# SHOW wal_level;
 wal_level
postgres=# -----------
 logical
postgres=# -- 'logical' includes everything 'replica' does
postgres=# -- Streaming replication still works with wal_level=logical
```

### Step 2: Create Tables (Publisher)
**Explanation:** Next, we need tables to replicate. Let us create sample tables on the publisher. Important: logical replication requires that published tables have a primary key or a REPLICA IDENTITY. Without one, UPDATE and DELETE operations cannot be replicated because the subscriber cannot identify which row to modify.

```sql
postgres=# -- Create tables with PRIMARY KEY:
postgres=# CREATE TABLE customers (
    id serial PRIMARY KEY,
    name text NOT NULL,
    email text UNIQUE,
    created_at timestamptz DEFAULT now()
);
postgres=# CREATE TABLE orders (
    id serial PRIMARY KEY,
    customer_id int REFERENCES customers(id),
    amount numeric(10,2),
    status text DEFAULT 'pending',
    ordered_at timestamptz DEFAULT now()
);
postgres=# -- Insert sample data:
postgres=# INSERT INTO customers (name, email) VALUES
    ('Alice', 'alice@example.com'),
    ('Bob', 'bob@example.com');
postgres=# INSERT INTO orders (customer_id, amount) VALUES
    (1, 99.99), (2, 149.50);
```

### Step 3: Create Publication (Publisher)
**Explanation:** Now create the publication on the publisher. A publication defines which tables to share. You can publish specific tables, all tables, or all tables with filters.

```sql
postgres=# -- Publish specific tables:
postgres=# CREATE PUBLICATION my_pub
    FOR TABLE customers, orders;
postgres=# CREATE PUBLICATION
postgres=# -- Or publish ALL tables in the database:
postgres=# -- CREATE PUBLICATION all_pub FOR ALL TABLES;
postgres=# -- Verify:
postgres=# SELECT * FROM pg_publication;
  pubname  | pubowner | puballtables | pubinsert | pubupdate | pubdelete
postgres=# -----------+----------+--------------+-----------+-----------+----------
 my_pub    |       10 | f            | t         | t         | t
postgres=# -- See which tables are published:
postgres=# SELECT * FROM pg_publication_tables;
  pubname  | schemaname | tablename
postgres=# -----------+------------+-----------
 my_pub    | public     | customers
 my_pub    | public     | orders
```

### Step 4: Create Tables on Subscriber
**Explanation:** On the subscriber side, you need to create the same table structure. Logical replication does NOT replicate schema changes — DDL is not replicated. You must create tables manually on the subscriber before subscribing. The column names and types must match, but the subscriber can have additional columns or different indexes.

```sql
postgres=# -- Create matching tables (same structure):
postgres=# CREATE TABLE customers (
    id serial PRIMARY KEY,
    name text NOT NULL,
    email text UNIQUE,
    created_at timestamptz DEFAULT now()
);
postgres=# CREATE TABLE orders (
    id serial PRIMARY KEY,
    customer_id int REFERENCES customers(id),
    amount numeric(10,2),
    status text DEFAULT 'pending',
    ordered_at timestamptz DEFAULT now()
);
postgres=# -- Subscriber can also have extra local tables:
postgres=# CREATE TABLE local_analytics (
    id serial PRIMARY KEY,
    metric text,
    value numeric
);
postgres=# -- This table is local-only, not replicated
```

### Step 5: Authentication (Publisher)
**Explanation:** On the publisher database, we must grant necessary permissions. Execute GRANT USAGE ON SCHEMA public TO rep_user, and GRANT SELECT ON ALL TABLES IN SCHEMA public TO rep_user. In pg_hba.conf, add a host entry permitting rep_user to authenticate from the subscriber IP using scram-sha-256.

```sql
# pg_hba.conf on PUBLISHER:
# host  mydb  replicator  10.0.2.10/32  scram-sha-256
#
# Note: for logical replication, use the DATABASE NAME
# (not 'replication' keyword like streaming replication)
# The subscriber connects to the actual database
# Reload:
sudo -u postgres psql -c "SELECT pg_reload_conf();"
# The replicator role needs SELECT on published tables:
sudo -u postgres psql -d mydb -c "
postgres=# GRANT SELECT ON customers, orders TO replicator;
"
```

### Step 6: Create Subscription (Subscriber)
**Explanation:** Now the exciting part — create the subscription on the subscriber. This one command does everything: connects to the publisher, creates a logical replication slot, copies existing data, and starts streaming changes.

```sql
postgres=# CREATE SUBSCRIPTION my_sub
    CONNECTION 'host=10.0.1.1 port=5432
      dbname=mydb user=replicator password=SecurePass123!'
    PUBLICATION my_pub;
NOTICE:  created replication slot "my_sub" on publisher
postgres=# CREATE SUBSCRIPTION
postgres=# -- What just happened:
postgres=# -- 1. Connected to publisher at 10.0.1.1
postgres=# -- 2. Created logical replication slot 'my_sub' on publisher
postgres=# -- 3. Started initial table sync (copies existing data)
postgres=# -- 4. Began streaming new changes
postgres=# -- Verify data was copied:
postgres=# SELECT * FROM customers;
 id | name  |      email          |         created_at
postgres=# ----+-------+---------------------+---------------------------
  1 | Alice | alice@example.com   | 2026-11-04 11:00:00+00
  2 | Bob   | bob@example.com     | 2026-11-04 11:00:01+00
```

### Test: INSERT on Publisher → Subscriber
**Explanation:** Now let us verify real-time logical replication. Execute an INSERT on the publisher orders table. Within milliseconds, the publisher wal_sender process decodes the logical change from WAL, sends it across TCP to the subscriber wal_receiver, and the row appears immediately when querying the subscriber table.

```sql
postgres=# -- ON PUBLISHER:
postgres=# INSERT INTO customers (name, email)
postgres-# VALUES ('Charlie', 'charlie@example.com');
postgres=# INSERT INTO orders (customer_id, amount)
postgres-# VALUES (3, 250.00);
postgres=# -- ON SUBSCRIBER (within milliseconds):
postgres=# SELECT * FROM customers WHERE name = 'Charlie';
 id |  name   |        email         |         created_at
postgres=# ----+---------+----------------------+---------------------------
  3 | Charlie | charlie@example.com  | 2026-11-04 11:30:00+00
postgres=# SELECT * FROM orders WHERE customer_id = 3;
 id | customer_id | amount | status  |        ordered_at
postgres=# ----+-------------+--------+---------+---------------------------
  3 |           3 | 250.00 | pending | 2026-11-04 11:30:01+00
```

### Test: UPDATE and DELETE Replication
**Explanation:** Updates and deletes also replicate. But remember — for UPDATE and DELETE to work, the table must have a primary key or a REPLICA IDENTITY that the subscriber can use to find the correct row.

```sql
postgres=# -- ON PUBLISHER:
postgres=# UPDATE orders SET status = 'shipped'
postgres-# WHERE id = 1;
postgres=# DELETE FROM orders WHERE id = 2;
postgres=# -- ON SUBSCRIBER:
postgres=# SELECT * FROM orders;
 id | customer_id | amount | status  |        ordered_at
postgres=# ----+-------------+--------+---------+---------------------------
  1 |           1 |  99.99 | shipped | 2026-11-04 11:00:05+00
  3 |           3 | 250.00 | pending | 2026-11-04 11:30:01+00
postgres=# -- id=2 is gone (deleted), id=1 status changed to 'shipped'
```

### REPLICA IDENTITY — Required for UPDATE/DELETE
**Explanation:** A critical requirement: REPLICA IDENTITY. Every published table needs a way to identify rows for UPDATE and DELETE. The default is the primary key. If a table has no primary key, you must explicitly set REPLICA IDENTITY to FULL or to a unique index.

```sql
postgres=# -- Check current replica identity:
postgres=# SELECT relname, relreplident
postgres-# FROM pg_class
postgres-# WHERE relname IN ('customers', 'orders');
 relname   | relreplident
postgres=# -----------+--------------
 customers | d
 orders    | d
postgres=# -- d = default (primary key) — this is correct
postgres=# -- For a table WITHOUT a primary key:
postgres=# CREATE TABLE logs (ts timestamptz, msg text);
postgres=# -- Try to publish it:
postgres=# ALTER PUBLICATION my_pub ADD TABLE logs;
postgres=# -- Works, but UPDATE/DELETE will FAIL on subscriber:
postgres=# -- ERROR: cannot update table "logs" because it does not
postgres=# --   have a replica identity
postgres=# -- Fix: set REPLICA IDENTITY FULL
postgres=# ALTER TABLE logs REPLICA IDENTITY FULL;
postgres=# -- Now UPDATE/DELETE compare ALL columns to find the row
postgres=# -- Slower but works without a primary key
```

### Monitoring Logical Replication
**Explanation:** You can monitor logical replication on both sides. On the publisher, check pg_stat_replication and pg_replication_slots. On the subscriber, check pg_stat_subscription and pg_subscription_rel for table sync status.

```sql
postgres=# -- ON PUBLISHER — replication slots:
postgres=# SELECT slot_name, slot_type, active,
    pg_size_pretty(
      pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)
    ) AS lag
postgres-# FROM pg_replication_slots
postgres-# WHERE slot_type = 'logical';
 slot_name | slot_type | active |   lag
postgres=# -----------+-----------+--------+----------
 my_sub    | logical   | t      | 0 bytes
postgres=# -- ON SUBSCRIBER — subscription status:
postgres=# SELECT subname, received_lsn, latest_end_lsn
postgres-# FROM pg_stat_subscription;
 subname | received_lsn | latest_end_lsn
postgres=# ---------+--------------+----------------
 my_sub  | 0/A000148    | 0/A000148
postgres=# -- Per-table sync status:
postgres=# SELECT srsubid, srrelid::regclass, srsubstate
postgres-# FROM pg_subscription_rel;
postgres=# -- srsubstate: i=init, d=data copy, s=synced, r=ready
```

### Row Filtering (PG 15+)
**Explanation:** You can publish a subset of rows using row filters. In PostgreSQL 16, publications support WHERE clauses to filter which rows are replicated.

```sql
postgres=# -- Publish only shipped orders:
postgres=# CREATE PUBLICATION shipped_pub
    FOR TABLE orders WHERE (status = 'shipped');
postgres=# -- Publish only customers created this year:
postgres=# CREATE PUBLICATION recent_pub
    FOR TABLE customers
postgres-# WHERE (created_at >= '2026-01-01');
postgres=# -- Combine: specific tables with filters:
postgres=# CREATE PUBLICATION filtered_pub
    FOR TABLE
        customers,
        orders WHERE (amount > 100);
postgres=# -- Verify filters:
postgres=# SELECT * FROM pg_publication_tables;
   pubname     | schemaname | tablename | rowfilter
postgres=# ---------------+------------+-----------+------------------
 filtered_pub  | public     | customers |
 filtered_pub  | public     | orders    | (amount > 100)
```

### Column Lists (PG 15+)
**Explanation:** You can also publish specific columns instead of the entire row. Column lists were introduced in PostgreSQL 15.

```sql
postgres=# -- Publish only specific columns:
postgres=# CREATE PUBLICATION partial_pub
    FOR TABLE customers (id, name);
postgres=# -- Only id and name columns are replicated
postgres=# -- email and created_at are NOT sent
postgres=# -- Subscriber table must have at least these columns:
postgres=# -- CREATE TABLE customers (
postgres=# --     id int PRIMARY KEY,
postgres=# --     name text
postgres=# -- );
postgres=# -- Useful for:
postgres=# -- Privacy: don't replicate email/phone to analytics DB
postgres=# -- Bandwidth: skip large text/json columns
postgres=# -- Compliance: keep PII on the publisher only
```

### Managing Publications & Subscriptions
**Explanation:** Managing publications and subscriptions. You can add or remove tables from a publication, and you can enable or disable a subscription without dropping it.

```sql
postgres=# -- ON PUBLISHER — add/remove tables:
postgres=# ALTER PUBLICATION my_pub ADD TABLE logs;
postgres=# ALTER PUBLICATION my_pub DROP TABLE logs;
postgres=# -- Refresh subscription after pub changes (on SUBSCRIBER):
postgres=# ALTER SUBSCRIPTION my_sub REFRESH PUBLICATION;
postgres=# -- Disable subscription (pause replication):
postgres=# ALTER SUBSCRIPTION my_sub DISABLE;
postgres=# -- Enable subscription (resume):
postgres=# ALTER SUBSCRIPTION my_sub ENABLE;
postgres=# -- Drop subscription (removes slot on publisher too):
postgres=# DROP SUBSCRIPTION my_sub;
postgres=# -- Drop publication:
postgres=# DROP PUBLICATION my_pub;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Logical replication copies row-level changes using publications and subscriptions. The publisher needs wal_level = logical. Published tables need primary keys or REPLICA IDENTITY for UPDATE and DELETE. The subscriber is read-write and can have local tables. DDL, sequences, and large objects are NOT replicated. You can filter by rows and columns. Common use cases: selective sync, cross-version migration, and CDC. In the next class, we cover advanced logical replication — logical decoding, wal2json, and Debezium for CDC pipelines.

- **Publisher: wal_level = logical (restart required)**
- **CREATE PUBLICATION for specific tables or ALL TABLES**
- **Tables need PRIMARY KEY or REPLICA IDENTITY**
- **Subscriber: create matching tables first (DDL not replicated)**
- **CREATE SUBSCRIPTION connects, syncs, and streams changes**
- **Subscriber is read-write (unlike streaming standby)**
- **NOT replicated: DDL, sequences, large objects**
- **Row filters: WHERE clause on publication (PG 15+)**
- **Column lists: publish specific columns (PG 15+)**
- **Use case: zero-downtime major version upgrade**
- **ALTER SUBSCRIPTION ... REFRESH PUBLICATION after changes**
- **Next: Logical Replication Advanced — Decoding & CDC**


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
