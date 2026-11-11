# Citus — Distributed PostgreSQL
**Series:** PostgreSQL Mastery | **Phase:** Phase 26: Extensions | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! What happens when your PostgreSQL database hits the limits of a single server? More data than one disk can hold, more queries than one CPU can process, more writes than one machine can handle. Citus is a PostgreSQL extension that distributes your tables across multiple nodes. It shards data horizontally, routes queries to the right shards, and lets you scale PostgreSQL to handle terabytes of data and thousands of concurrent queries. Let us learn the fundamentals.


---

## 2. Core Technical Concepts & Mechanisms

### Citus Architecture
Citus adds a coordinator node and multiple worker nodes. The coordinator receives queries, plans the distributed execution, and combines results. Workers store the actual data shards. Your application connects only to the coordinator — it looks like a single PostgreSQL database.

```
[Application]
[Coordinator Node]
[Worker 1
Shards 1-32]
[Worker 2
Shards 33-64]
[Worker 3
Shards 65-96]
```

### Citus Table Types
There are three types of distributed tables in Citus. Distributed tables are sharded by a distribution column — this is the main type. Reference tables are small lookup tables replicated to every worker. Local tables stay on the coordinator only — for data that does not need distribution.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Distributed Table** | Sharded across workers by a distribution column (e.g., tenant_id) |
| **Reference Table** | Small table replicated to ALL workers — for lookups and joins |
| **Local Table** | Stays on coordinator only — for config, metadata, small tables |

**Notes:**
- Choose distribution column carefully — it determines query performance
- Most queries should filter on the distribution column
- Reference tables are for small, frequently joined lookup data

### Choosing the Distribution Column
The distribution column is the most important decision in Citus. Queries that filter by the distribution column are routed to a single shard — fast. Queries without it must scatter to all shards and gather results — slower. Choose a column with high cardinality that appears in most WHERE clauses.

| Good Distribution Columns | Bad Distribution Columns |
| :--- | :--- |
| tenant_id (multi-tenant SaaS) | created_at (causes hot shards) |
| user_id (per-user data) | status (too few distinct values) |
| device_id (IoT data) | country (data skew) |
| High cardinality (many distinct values) | Boolean columns (only 2 values) |
| Present in most WHERE clauses | Columns rarely in WHERE |
| Present in most JOIN conditions | Columns not in JOINs |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Citus Use Cases
Multi-tenant SaaS is the most common Citus use case. Each tenant's data lives on one shard. Queries filter by tenant_id so they hit only one worker. You can serve thousands of tenants from the same database without them interfering with each other.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Multi** | tenant SaaS is the most common Citus use case |
| **Point 2** | Each tenant's data lives on one shard |
| **Point 3** | Queries filter by tenant_id so they hit only one worker |
| **Point 4** | You can serve thousands of tenants from the same database without them interfering with each other |

### Citus Constraints & Limitations
Important constraints with Citus. The distribution column must be part of every primary key and unique constraint. Foreign keys must include the distribution column. Transactions that span multiple shards use two-phase commit — slower than single-shard transactions. Plan your schema around co-location.

| Must Do | Limitations |
| :--- | :--- |
| Include dist column in PRIMARY KEY | Cross-shard transactions are slower |
| Include dist column in UNIQUE constraints | Cannot change distribution column later |
| Include dist column in foreign keys | Some window functions limited |
| Include dist column in JOIN conditions | CTEs may not push down fully |
| Co-locate related tables (same dist column) | Sequences not globally unique by default |
| Filter by dist column when possible | Requires careful schema planning upfront |


---

## 3. Hands-On Commands & psql Output

### Installing Citus
**Explanation:** Install Citus. It requires a package install and shared_preload_libraries configuration on every node — both the coordinator and all workers. After restart, create the extension and register the worker nodes.

```sql
postgres=# -- 1. Install the package (on ALL nodes):
postgres=# -- Debian/Ubuntu:
postgres=# --   sudo apt install postgresql-16-citus-12.1
postgres=# -- RHEL/Rocky:
postgres=# --   sudo dnf install citus_16
postgres=# -- 2. Edit postgresql.conf (on ALL nodes):
postgres=# --   shared_preload_libraries = 'citus'
postgres=# -- 3. Restart PostgreSQL (on ALL nodes):
postgres=# --   sudo systemctl restart postgresql-16
postgres=# -- 4. Create extension (on ALL nodes):
postgres=# CREATE EXTENSION citus;
postgres=# -- 5. On the COORDINATOR, add workers:
postgres=# SELECT citus_set_coordinator_host('coord-node', 5432);
postgres=# SELECT citus_add_node('worker-1', 5432);
postgres=# SELECT citus_add_node('worker-2', 5432);
postgres=# SELECT citus_add_node('worker-3', 5432);
postgres=# -- Verify:
postgres=# SELECT * FROM citus_get_active_worker_nodes();
postgres=# -- worker-1 | 5432
postgres=# -- worker-2 | 5432
postgres=# -- worker-3 | 5432
```

### Creating Distributed Tables
**Explanation:** Create a distributed table. First create the table normally, then distribute it with create_distributed_table. Choose the distribution column wisely — it should be the column you filter by most often. For multi-tenant applications, tenant_id is the obvious choice.

```sql
postgres=# -- Create table normally:
postgres=# CREATE TABLE orders (
    id bigserial,
    tenant_id int NOT NULL,
    product text NOT NULL,
    amount numeric(10,2),
    created_at timestamptz DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
postgres=# -- Distribute by tenant_id:
postgres=# SELECT create_distributed_table('orders', 'tenant_id');
postgres=# -- Citus creates 32 shards by default across workers
postgres=# -- All rows with the same tenant_id go to the same shard
postgres=# -- Insert works exactly like normal:
postgres=# INSERT INTO orders (tenant_id, product, amount)
postgres-# VALUES (1, 'Widget', 29.99);
postgres=# INSERT INTO orders (tenant_id, product, amount)
postgres-# VALUES (2, 'Gadget', 49.99);
postgres=# -- Query with tenant filter → goes to one worker:
postgres=# SELECT * FROM orders WHERE tenant_id = 1;
postgres=# -- Routed to the worker holding tenant 1's shard
```

### Reference Tables — Replicated Lookups
**Explanation:** Reference tables are for small lookup tables that need to join with distributed tables on every worker. Countries, categories, product types — these are replicated to all workers so joins are local and fast.

```sql
postgres=# -- Create and distribute as reference table:
postgres=# CREATE TABLE countries (
    id int PRIMARY KEY,
    name text NOT NULL,
    code char(2) UNIQUE
);
postgres=# SELECT create_reference_table('countries');
postgres=# -- Replicated to ALL workers
postgres=# INSERT INTO countries VALUES
(1, 'United States', 'US'),
(2, 'United Kingdom', 'GB'),
(3, 'Germany', 'DE');
postgres=# -- Joins with distributed tables are fast:
postgres=# -- (each worker has a local copy of countries)
postgres=# SELECT o.product, c.name AS country
postgres-# FROM orders o
postgres-# JOIN countries c ON o.country_id = c.id
postgres-# WHERE o.tenant_id = 1;
postgres=# -- Executed entirely on one worker — no network round-trips!
```

### Query Routing — Single-Shard vs Multi-Shard
**Explanation:** Queries in Citus are transparent — you write standard SQL. When you filter by the distribution column, Citus routes the query to a single worker. When you do not, Citus scatters the query to all workers, executes in parallel, and gathers the results.

```sql
postgres=# -- Single-shard query (fast — one worker):
postgres=# EXPLAIN SELECT * FROM orders WHERE tenant_id = 1;
postgres=# -- Custom Scan (Citus Adaptive)
postgres=# --   Task Count: 1  -- Only 1 shard!
postgres=# -- Multi-shard query (parallel across all workers):
postgres=# EXPLAIN SELECT count(*), sum(amount) FROM orders;
postgres=# -- Custom Scan (Citus Adaptive)
postgres=# --   Task Count: 32  -- All 32 shards!
postgres=# -- Aggregations run in parallel:
postgres=# SELECT tenant_id, count(*), sum(amount)
postgres-# FROM orders
postgres-# GROUP BY tenant_id
postgres-# ORDER BY sum(amount) DESC
postgres-# LIMIT 10;
postgres=# -- Each worker aggregates locally,
postgres=# -- coordinator combines results
```

### Co-located Joins (Same Distribution Column)
**Explanation:** Co-located joins are a key Citus optimization. When two distributed tables share the same distribution column, rows with the same value are on the same worker. Joins between them are local — no data shuffling across the network.

```sql
postgres=# -- Create another table with same distribution:
postgres=# CREATE TABLE order_items (
    id bigserial,
    tenant_id int NOT NULL,
    order_id bigint NOT NULL,
    product_name text,
    quantity int,
    PRIMARY KEY (tenant_id, id)
);
postgres=# -- MUST use same distribution column:
postgres=# SELECT create_distributed_table('order_items', 'tenant_id');
postgres=# -- Co-located join — fast! No network shuffle:
postgres=# SELECT o.id, o.amount, oi.product_name, oi.quantity
postgres-# FROM orders o
postgres-# JOIN order_items oi ON o.tenant_id = oi.tenant_id
postgres-# AND o.id = oi.order_id
postgres-# WHERE o.tenant_id = 1;
postgres=# -- Entire join executed on one worker!
postgres=# -- Include tenant_id in ALL joins for co-location:
postgres=# -- WRONG: JOIN ON order_id only (forces repartition)
postgres=# -- RIGHT: JOIN ON tenant_id AND order_id (co-located)
```

### Schema Changes on Distributed Tables
**Explanation:** Citus supports common DDL operations transparently. ALTER TABLE, CREATE INDEX, and other schema changes propagate to all workers automatically. You manage the schema from the coordinator — Citus handles the distribution.

```sql
postgres=# -- Add column — propagated to all workers:
postgres=# ALTER TABLE orders ADD COLUMN status text DEFAULT 'pending';
postgres=# -- Create index — created on all shards:
postgres=# CREATE INDEX idx_orders_status ON orders (tenant_id, status);
postgres=# -- Add constraint:
postgres=# ALTER TABLE orders
ADD CONSTRAINT positive_amount CHECK (amount > 0);
postgres=# -- View shard distribution:
postgres=# SELECT * FROM citus_shards
postgres-# WHERE table_name = 'orders'::regclass
postgres-# LIMIT 5;
postgres=# -- shard_id | shard_name | table_name | node
postgres=# -- 102008   | orders_102008 | orders | worker-1
postgres=# -- 102009   | orders_102009 | orders | worker-2
postgres=# -- Rebalance shards after adding a worker:
postgres=# -- SELECT citus_rebalance_start();
```

### Beginner Traps
**Explanation:** A beginner trap — distributing by a column with low cardinality like status or country. This causes data skew — one shard gets most of the data while others sit empty. Also, forgetting to include the distribution column in joins forces expensive cross-shard repartitioning.

```sql
postgres=# -- TRAP 1: Low cardinality distribution
postgres=# SELECT create_distributed_table('logs', 'status');
postgres=# -- Only 3 values: 'ok', 'warn', 'error'
postgres=# -- Result: 3 hot shards, 29 empty shards!
postgres=# -- TRAP 2: Missing dist column in PRIMARY KEY
postgres=# CREATE TABLE bad_table (
    id serial PRIMARY KEY,  -- no tenant_id!
    tenant_id int
);
postgres=# SELECT create_distributed_table('bad_table', 'tenant_id');
postgres=# -- ERROR: cannot create constraint on "bad_table"
postgres=# -- because the table is distributed and the
postgres=# -- constraint does not include the distribution column
postgres=# -- FIX: composite primary key
postgres=# CREATE TABLE good_table (
    id bigserial,
    tenant_id int NOT NULL,
    PRIMARY KEY (tenant_id, id)  -- includes dist column!
);
postgres=# -- TRAP 3: Joining without dist column
postgres=# -- SLOW: forces repartition
postgres=# SELECT * FROM orders o JOIN order_items oi
postgres-# ON o.id = oi.order_id;
postgres=# -- FAST: co-located join
postgres=# SELECT * FROM orders o JOIN order_items oi
postgres-# ON o.tenant_id = oi.tenant_id
postgres-# AND o.id = oi.order_id;
```

### Single-Node Citus (Dev & Testing)
**Explanation:** You can also run Citus on a single node for testing and development. Single-node Citus creates local shards — you get the same sharding behavior without multiple servers. This is great for development and testing before deploying to a cluster.

```sql
postgres=# -- Single-node setup (no workers needed):
postgres=# CREATE EXTENSION citus;
postgres=# -- Set this node as coordinator:
postgres=# SELECT citus_set_coordinator_host('localhost', 5432);
postgres=# -- Create distributed table — shards are local:
postgres=# CREATE TABLE events (
    id bigserial,
    tenant_id int NOT NULL,
    event_type text,
    payload jsonb,
    created_at timestamptz DEFAULT now(),
    PRIMARY KEY (tenant_id, id)
);
postgres=# SELECT create_distributed_table('events', 'tenant_id');
postgres=# -- Works the same — just all shards on one machine:
postgres=# INSERT INTO events (tenant_id, event_type, payload)
postgres-# VALUES (1, 'login', '{"ip": "10.0.0.1"}');
postgres=# SELECT * FROM events WHERE tenant_id = 1;
postgres=# -- Same SQL, same behavior
postgres=# -- Add workers later to scale out
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
A beginner trap — distributing by a column with low cardinality like status or country. This causes data skew — one shard gets most of the data while others sit empty. Also, forgetting to include the distribution column in joins forces expensive cross-shard repartitioning.

```sql
-- TRAP 1: Low cardinality distribution
SELECT create_distributed_table('logs', 'status');
-- Only 3 values: 'ok', 'warn', 'error'
-- Result: 3 hot shards, 29 empty shards!
-- TRAP 2: Missing dist column in PRIMARY KEY
CREATE TABLE bad_table (
    id serial PRIMARY KEY,  -- no tenant_id!
    tenant_id int
);
SELECT create_distributed_table('bad_table', 'tenant_id');
-- ERROR: cannot create constraint on "bad_table"
-- because the table is distributed and the
-- constraint does not include the distribution column
-- FIX: composite primary key
CREATE TABLE good_table (
    id bigserial,
    tenant_id int NOT NULL,
    PRIMARY KEY (tenant_id, id)  -- includes dist column!
);
-- TRAP 3: Joining without dist column
-- SLOW: forces repartition
SELECT * FROM orders o JOIN order_items oi
ON o.id = oi.order_id;
-- FAST: co-located join
SELECT * FROM orders o JOIN order_items oi
ON o.tenant_id = oi.tenant_id
AND o.id = oi.order_id;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Citus distributes PostgreSQL tables across multiple nodes. Distributed tables are sharded by a distribution column — choose wisely. Reference tables are replicated to all workers for fast joins. Queries with the distribution column hit one shard — fast. Queries without it scatter to all shards — parallel but slower. Co-locate related tables on the same distribution column. Include the distribution column in all keys and joins. In the next class, we learn pgAudit for compliance-grade audit logging.

- **Extension for distributed PostgreSQL**
- **Coordinator + Worker architecture**
- **create_distributed_table(): shard by column**
- **create_reference_table(): replicate to all**
- **Distribution column = most important decision**
- **Single-shard queries = fast (one worker)**
- **Multi-shard queries = parallel (all workers)**
- **Co-locate related tables (same dist column)**
- **Include dist column in PK, UNIQUE, FK, JOINs**
- **Single-node Citus for dev/testing**
- **Next: pgAudit — Compliance Audit Logging**


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
