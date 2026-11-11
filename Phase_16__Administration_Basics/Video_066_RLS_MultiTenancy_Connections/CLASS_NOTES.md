# RLS, Multi-Tenancy & Connections
**Series:** PostgreSQL Mastery | **Phase:** Phase 16: Administration Basics | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover three topics that bring your database security to production level. First, Row-Level Security — policies that control which rows each user can see and modify. Second, schema-based multi-tenancy — isolating different customers' data using schemas. Third, connection management — max_connections limits, connection pooling with PgBouncer, and monitoring idle connections. Let us begin.

### The Problem: Table-Level vs Row-Level
Here is the problem. GRANT and REVOKE control access to entire tables — either you can SELECT from the orders table or you cannot. But what if you have one orders table shared by multiple tenants, and each tenant should only see their own orders? You cannot solve this with table-level permissions. You need row-level permissions. That is what Row-Level Security does — it adds an invisible WHERE clause to every query, so each user sees only the rows they are allowed to see.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Table-Level vs Row-Level
Here is the problem. GRANT and REVOKE control access to entire tables — either you can SELECT from the orders table or you cannot. But what if you have one orders table shared by multiple tenants, and each tenant should only see their own orders? You cannot solve this with table-level permissions. You need row-level permissions. That is what Row-Level Security does — it adds an invisible WHERE clause to every query, so each user sees only the rows they are allowed to see.

| GRANT/REVOKE (Table-Level) | RLS (Row-Level Security) |
| :--- | :--- |
| All or nothing on the table | Per-row access control |
| Can SELECT all rows or no rows | Each user sees only their rows |
| Cannot filter by tenant/owner | Invisible WHERE clause added |
| One table = one permission | Same table, different views |

### PERMISSIVE vs RESTRICTIVE Policies
Permissive versus restrictive policies. By default, policies are PERMISSIVE — if any permissive policy allows access, the row is visible. Multiple permissive policies combine with OR logic. A RESTRICTIVE policy combines with AND logic — it must pass in addition to all permissive policies. Use restrictive policies to add additional security layers, like requiring that an account is active AND the tenant matches.

| PERMISSIVE (default) | RESTRICTIVE |
| :--- | :--- |
| Multiple policies combine with OR | Combines with AND logic |
| Any one passing = row visible | Must pass in ADDITION to permissive |
| Good for: additive access | Good for: extra security layers |
| Example: owner OR admin can see | Example: must be active AND tenant |

### Beginner Trap: RLS Enabled, No Policies = No Data
Another trap: you enable RLS but create no policies. With RLS enabled and zero policies, no rows are visible — SELECT returns empty. No rows can be inserted, updated, or deleted. This is the secure default, but it catches beginners who enable RLS and wonder why their table seems empty. Always create at least one policy right after enabling RLS.

- 1 -- ALTER TABLE secret_data ENABLE ROW LEVEL SECURITY;
- 2 -- No CREATE POLICY statement
- 3 -- SELECT * FROM secret_data; → 0 rows (empty!)
- 4 -- INSERT fails: new row violates row-level security policy
- 5 -- CREATE POLICY ... right after ALTER TABLE ENABLE RLS

### RLS vs Schema Isolation Decision
Here is when to choose each approach. RLS with a shared table is simpler — one table, one set of indexes, one backup. But it requires every query to filter by tenant, and a bug in the policy leaks data across tenants. Schema isolation is more complex — separate tables, separate indexes, separate migrations per schema. But it is physically impossible for tenant A to see tenant B's data, and you can do per-tenant backups and restores.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Here** | when to choose each approach |
| **RLS with a shared table** | simpler — one table, one set of indexes, one backup |
| **But it** | every query to filter by tenant, and a bug in the policy leaks data across tenants |
| **Schema isolation** | more complex — separate tables, separate indexes, separate migrations per schema |

### Connection Cost Breakdown
Now connection management. Every PostgreSQL connection costs memory — about 5 to 10 megabytes for the backend process, plus work_mem for each sort operation. If max_connections is 200 and every connection runs a sorting query, that is 200 times work_mem in extra memory. More connections also means more lock contention and context switching. The rule: fewer connections with a pooler performs better than many direct connections.

- 1 -- PostgreSQL forks a new backend process per connection (~5-10MB each)
- 2 -- 200 connections × 32MB work_mem × 3 sorts = 19.2GB worst case
- 3 -- More connections = more processes competing for locks
- 4 -- OS spends more time switching between processes than doing work
- 5 -- Past ~100 connections, throughput decreases even as connections increase

### PgBouncer — Connection Pooling
PgBouncer is a lightweight connection pooler that sits between your application and PostgreSQL. Instead of each application request opening a direct connection to PostgreSQL, it connects to PgBouncer, which maintains a small pool of real PostgreSQL connections. 1000 application connections can share 50 real database connections. PgBouncer has three pooling modes: session, transaction, and statement.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Session Mode** | Client keeps a PG connection for the entire session. Safest but least efficient. |
| **Transaction Mode** | Client gets a PG connection only during a transaction. Returned to pool between transactions. RECOMMENDED. |
| **Statement Mode** | Connection returned after each statement. Cannot use multi-statement transactions. |

**Notes:**
- PgBouncer uses ~2KB per client connection (vs ~10MB for PG)
- Transaction mode: most common in production
- Session features (LISTEN/NOTIFY, prepared statements) need session mode

### Beginner Trap: max_connections = 1000
Here is a beginner trap: your application runs out of connections, so you increase max_connections to 1000. Performance gets worse, not better. With 1000 active connections, PostgreSQL spends more time on context switching than on actual query work. The fix is never to increase max_connections above 200 — use PgBouncer instead. 50 real connections in PgBouncer can serve 1000 application connections more efficiently than 1000 direct connections.

| Wrong: Raise max_connections | Right: Use PgBouncer |
| :--- | :--- |
| max_connections = 1000 | max_connections = 100 |
| 1000 backend processes (10GB RAM) | PgBouncer pool_size = 50 |
| Massive context switching | App connects to PgBouncer |
| Lock contention explodes | 1000 app conns → 50 PG conns |
| Performance DECREASES | Same throughput, 1/20 memory |

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us look at the decision framework.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Decision Framework: Isolation & Connections
Here is the complete decision framework for data isolation and connection management in production.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the complete decision framework for data isolation and connection management in production |

### Practice Exercises
Time to practice. First, create a tasks table with a user_id column, enable RLS, and create a policy so each user sees only their own tasks — use current_user as the match condition. Second, test by connecting as different users and verifying isolation. Third, create two schemas for two tenants with identical table structures, insert different data, and switch with SET search_path. Fourth, query pg_stat_activity to see your current connections and their states. Fifth, set idle_in_transaction_session_timeout to 2 minutes using ALTER SYSTEM.

- 1 -- CREATE TABLE tasks, ENABLE RLS, POLICY using current_user
- 2 -- SET ROLE user_a, SELECT. SET ROLE user_b, SELECT. Different results.
- 3 -- CREATE SCHEMA tenant_a/b, same table, SET search_path, INSERT/SELECT
- 4 -- SELECT state, count(*) FROM pg_stat_activity GROUP BY state;
- 5 -- ALTER SYSTEM SET idle_in_transaction_session_timeout = '2min';


---

## 3. Hands-On Commands & psql Output

### RLS: Enable + Create Policy
**Explanation:** Row-Level Security has two steps. First, enable RLS on the table with ALTER TABLE ENABLE ROW LEVEL SECURITY. Second, create one or more policies that define who can see or modify which rows. A policy has a name, applies to a role, covers specific operations, and defines a USING clause for reads and a WITH CHECK clause for writes. Without any policies, RLS blocks all access — not even SELECT returns rows. The table owner bypasses RLS unless you set FORCE ROW LEVEL SECURITY.

```sql
-- Step 1: Enable RLS on the table
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Step 2: Create a policy
CREATE POLICY policy_name ON table_name
    AS { PERMISSIVE | RESTRICTIVE }  -- default: PERMISSIVE
    FOR { ALL | SELECT | INSERT | UPDATE | DELETE }
    TO role_name           -- which role this applies to
    USING (condition)      -- filter for existing rows (reads)
    WITH CHECK (condition) -- filter for new/modified rows (writes)
;

-- Example: each user sees only their own orders
CREATE POLICY tenant_isolation ON orders
    FOR ALL
    TO PUBLIC
    USING (tenant_id = current_setting('app.tenant_id')::int)
    WITH CHECK (tenant_id = current_setting('app.tenant_id')::int);
```

### Building RLS: Tenant Isolation
**Explanation:** Let us build it live. We will create an orders table shared by multiple tenants, enable RLS, and create a policy so each tenant sees only their own orders. We use a session variable called app.tenant_id to identify the current tenant.

```sql
trigger_lab=# CREATE TABLE orders (
    id         SERIAL PRIMARY KEY,
    tenant_id  INT NOT NULL,
    product    TEXT NOT NULL,
    amount     NUMERIC(10,2),
    created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE
trigger_lab=# INSERT INTO orders (tenant_id, product, amount) VALUES
  (1, 'Widget', 99.99), (1, 'Gadget', 249.99),
  (2, 'Widget', 99.99), (2, 'Doohickey', 49.99),
  (3, 'Gadget', 249.99);
INSERT 0 5
trigger_lab=# ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE
trigger_lab=# CREATE POLICY tenant_isolation ON orders
    FOR ALL TO PUBLIC
    USING (tenant_id = current_setting('app.tenant_id')::int)
    WITH CHECK (tenant_id = current_setting('app.tenant_id')::int);
CREATE POLICY
```

### Testing RLS: Different Tenant Views
**Explanation:** Let us test the isolation. We grant Carol access to the orders table, then set the tenant_id session variable to different values. Carol should see only the rows matching her tenant_id. She cannot see or insert rows for other tenants. Watch how the same SELECT returns different results depending on the session variable.

```sql
trigger_lab=# GRANT SELECT, INSERT ON orders TO carol;
GRANT
trigger_lab=# GRANT USAGE ON SEQUENCE orders_id_seq TO carol;
GRANT
trigger_lab=# SET ROLE carol;
SET
trigger_lab=> SET app.tenant_id = '1';
SET
trigger_lab=> SELECT * FROM orders;
 id | tenant_id | product |  amount
----+-----------+---------+---------
  1 |         1 | Widget  |   99.99
  2 |         1 | Gadget  |  249.99
(2 rows)
trigger_lab=> SET app.tenant_id = '2';
SET
trigger_lab=> SELECT * FROM orders;
 id | tenant_id | product   |  amount
----+-----------+-----------+---------
  3 |         2 | Widget    |   99.99
  4 |         2 | Doohickey |   49.99
(2 rows)
```

### WITH CHECK: Blocking Wrong Writes
**Explanation:** The WITH CHECK clause prevents writing rows you should not own. If Carol's tenant_id is set to 1, she cannot insert a row with tenant_id 2 — the policy blocks it. This prevents a malicious or buggy application from writing data to the wrong tenant.

```sql
trigger_lab=> SET app.tenant_id = '1';
SET
trigger_lab=> -- Try to insert for tenant 2 while set as tenant 1:
trigger_lab=> INSERT INTO orders (tenant_id, product, amount) VALUES (2, 'Hack', 0.01);
ERROR:  new row violates row-level security policy for table "orders"
trigger_lab=> -- Correct tenant works:
trigger_lab=> INSERT INTO orders (tenant_id, product, amount) VALUES (1, 'Thingamajig', 19.99);
INSERT 0 1
trigger_lab=> RESET ROLE;
RESET
```

### Beginner Trap: Owner Bypasses RLS
**Explanation:** Here is a beginner trap with RLS: the table owner bypasses all policies. If you create a table as postgres and enable RLS, the postgres role still sees all rows. This is by design — the owner needs to manage the data. But in production, your application should not connect as the table owner. If you need the owner to also follow policies, use ALTER TABLE FORCE ROW LEVEL SECURITY.

```sql
trigger_lab=# -- postgres is the table owner — bypasses RLS:
trigger_lab=# SELECT count(*) FROM orders;
 count
-------
     6
(1 row)
-- -- Sees all 6 rows regardless of tenant_id policy!
-- 
-- -- To make owner ALSO follow policies:
trigger_lab=# ALTER TABLE orders FORCE ROW LEVEL SECURITY;
ALTER TABLE
-- -- Now even the owner must pass the policy.
-- -- Superusers ALWAYS bypass RLS — no workaround.
```

### Schema-Based Multi-Tenancy
**Explanation:** Now schema-based multi-tenancy — a different approach to isolating tenant data. Instead of one shared table with RLS, you create a separate schema for each tenant. Each schema has its own tables with identical structure. The application sets the search_path to the tenant's schema on each connection. This gives complete isolation — each tenant's data is in physically separate tables.

```sql
trigger_lab=# -- Create per-tenant schemas:
trigger_lab=# CREATE SCHEMA tenant_acme;
CREATE SCHEMA
trigger_lab=# CREATE SCHEMA tenant_globex;
CREATE SCHEMA
trigger_lab=# -- Same table structure in each schema:
trigger_lab=# CREATE TABLE tenant_acme.orders (id SERIAL PRIMARY KEY, product TEXT, amount NUMERIC);
CREATE TABLE
trigger_lab=# CREATE TABLE tenant_globex.orders (id SERIAL PRIMARY KEY, product TEXT, amount NUMERIC);
CREATE TABLE
trigger_lab=# -- App sets search_path per connection:
trigger_lab=# SET search_path TO tenant_acme, public;
SET
trigger_lab=# INSERT INTO orders (product, amount) VALUES ('Widget', 99.99);
INSERT 0 1
-- -- Goes into tenant_acme.orders automatically
```

### Monitoring and Managing Connections
**Explanation:** max_connections is the hard limit. The default is 100. But just because you set it to 100 does not mean 100 connections are healthy. Monitor active connections with pg_stat_activity. The idle_in_transaction_session_timeout parameter automatically kills connections that have been idle inside a transaction for too long — these hold locks and prevent vacuum. Set it to 5 minutes for most applications.

```sql
trigger_lab=# SHOW max_connections;
 max_connections
-----------------
 100
trigger_lab=# -- Active connections right now:
trigger_lab=# SELECT count(*) AS total,
  count(*) FILTER (WHERE state = 'active') AS active,
  count(*) FILTER (WHERE state = 'idle') AS idle,
  count(*) FILTER (WHERE state = 'idle in transaction') AS idle_in_tx
FROM pg_stat_activity WHERE backend_type = 'client backend';
 total | active | idle | idle_in_tx
-------+--------+------+-----------
     3 |      1 |    2 |          0
trigger_lab=# -- Auto-kill idle-in-transaction after 5 min:
trigger_lab=# ALTER SYSTEM SET idle_in_transaction_session_timeout = '5min';
ALTER SYSTEM
trigger_lab=# SELECT pg_reload_conf();
 pg_reload_conf
----------------
 t
```

### Connection Limits and Errors
**Explanation:** When you hit the connection limit, PostgreSQL returns FATAL: too many connections. You can also set per-role connection limits to prevent one application from monopolizing all connections. And always reserve a few connections for the superuser — superuser_reserved_connections ensures you can still connect to fix problems even when the database is full.

```sql
-- -- Error when limit reached:
FATAL:  too many connections for role "webapp"
FATAL:  sorry, too many clients already
-- 
trigger_lab=# -- Per-role connection limit:
trigger_lab=# ALTER ROLE webapp CONNECTION LIMIT 20;
ALTER ROLE
trigger_lab=# -- Reserve 3 connections for superuser:
trigger_lab=# SHOW superuser_reserved_connections;
 superuser_reserved_connections
--------------------------------
 3
(1 row)
-- -- With max_connections=100 and reserved=3:
-- -- Regular users can use 97 connections
-- -- Superuser can always use the last 3
```

### Managing RLS Policies
**Explanation:** Let us also look at how to manage existing RLS policies. You can list all policies on a table, alter them, or drop them. The pg_policies catalog view shows all policies across all tables.

```sql
trigger_lab=# -- List all policies on a table:
trigger_lab=# SELECT policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies WHERE tablename = 'orders';
    policyname     | permissive | roles  | cmd |                  qual                   | with_check
-------------------+------------+--------+-----+-----------------------------------------+-----------
 tenant_isolation  | PERMISSIVE | {public}| ALL | (tenant_id = (current_setting(...)::int))| (same)
(1 row)
trigger_lab=# -- Drop a policy:
trigger_lab=# DROP POLICY tenant_isolation ON orders;
DROP POLICY
trigger_lab=# -- Disable RLS entirely:
trigger_lab=# ALTER TABLE orders DISABLE ROW LEVEL SECURITY;
ALTER TABLE
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `pgbouncer.ini` — PgBouncer — Minimal Config (pgbouncer.ini)
Here is a minimal PgBouncer configuration. PgBouncer listens on port 6432, your application connects to 6432 instead of 5432, and PgBouncer forwards to PostgreSQL. The key settings are pool_size — how many real connections to maintain — and pool_mode — usually transaction. We will cover PgBouncer installation and advanced configuration in a later class.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `myapp` | `host=127.0.0.1 port=5432 dbname=myapp` | `[SETTING]` | Real PG connection |
| `` | `` | `[SETTING]` |  |
| `listen_addr` | `0.0.0.0` | `[SETTING]` | Listen on all interfaces |
| `listen_port` | `6432` | `[SETTING]` | PgBouncer port (not 5432!) |
| `pool_mode` | `transaction` | `[SETTING]` | Return conn after each TX |
| `default_pool_size` | `50` | `[SETTING]` | 50 real PG connections |
| `max_client_conn` | `1000` | `[SETTING]` | 1000 app connections allowed |
| `auth_type` | `scram-sha-256` | `[SETTING]` | Match PG auth method |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Owner Bypasses RLS
Here is a beginner trap with RLS: the table owner bypasses all policies. If you create a table as postgres and enable RLS, the postgres role still sees all rows. This is by design — the owner needs to manage the data. But in production, your application should not connect as the table owner. If you need the owner to also follow policies, use ALTER TABLE FORCE ROW LEVEL SECURITY.

```sql
-- postgres is the table owner — bypasses RLS:
SELECT count(*) FROM orders;
 count
-------
     6
(1 row)
-- Sees all 6 rows regardless of tenant_id policy!

-- To make owner ALSO follow policies:
ALTER TABLE orders FORCE ROW LEVEL SECURITY;
ALTER TABLE
-- Now even the owner must pass the policy.
-- Superusers ALWAYS bypass RLS — no workaround.
```

### Beginner Trap: RLS Enabled, No Policies = No Data
Another trap: you enable RLS but create no policies. With RLS enabled and zero policies, no rows are visible — SELECT returns empty. No rows can be inserted, updated, or deleted. This is the secure default, but it catches beginners who enable RLS and wonder why their table seems empty. Always create at least one policy right after enabling RLS.

- 1 -- ALTER TABLE secret_data ENABLE ROW LEVEL SECURITY;
- 2 -- No CREATE POLICY statement
- 3 -- SELECT * FROM secret_data; → 0 rows (empty!)
- 4 -- INSERT fails: new row violates row-level security policy
- 5 -- CREATE POLICY ... right after ALTER TABLE ENABLE RLS

### Beginner Trap: max_connections = 1000
Here is a beginner trap: your application runs out of connections, so you increase max_connections to 1000. Performance gets worse, not better. With 1000 active connections, PostgreSQL spends more time on context switching than on actual query work. The fix is never to increase max_connections above 200 — use PgBouncer instead. 50 real connections in PgBouncer can serve 1000 application connections more efficiently than 1000 direct connections.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. Row-Level Security adds invisible WHERE clauses per-user — USING for reads, WITH CHECK for writes. Table owners bypass RLS unless FORCE is set. Schema-based multi-tenancy gives physical isolation with search_path switching. Connection management: keep max_connections low, use PgBouncer for pooling, set idle_in_transaction_session_timeout to kill stale transactions, and reserve connections for superuser emergencies.

- **RLS: ENABLE RLS + CREATE POLICY with USING and WITH CHECK**
- **USING = read filter, WITH CHECK = write filter**
- **Table owner bypasses RLS — use FORCE for owner too**
- **No policies = no rows visible (secure default)**
- **PERMISSIVE policies: OR logic. RESTRICTIVE: AND logic**
- **Schema isolation: CREATE SCHEMA per tenant, SET search_path**
- **max_connections: keep ≤ 200, use PgBouncer for more**
- **PgBouncer transaction mode: 50 PG conns serve 1000 clients**
- **idle_in_transaction_session_timeout: auto-kill stale TX**
- **superuser_reserved_connections: emergency access guarantee**


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
