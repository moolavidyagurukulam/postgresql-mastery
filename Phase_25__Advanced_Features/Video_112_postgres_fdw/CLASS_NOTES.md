# postgres_fdw — Connect PostgreSQL to PostgreSQL
**Series:** PostgreSQL Mastery | **Phase:** Phase 25: Advanced Features | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous class, we learned the concept of Foreign Data Wrappers and used file_fdw for CSV files. Now we focus on the most powerful FDW — postgres_fdw. It connects one PostgreSQL server to another, letting you query, join, and even write to remote tables as if they were local. This is essential for distributed architectures, data warehousing, and cross-database queries.


---

## 2. Core Technical Concepts & Mechanisms

### postgres_fdw Server Options
postgres_fdw supports transactions across remote servers. By default, each remote statement runs in its own transaction. You can control this with the fetch_size and other options.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | postgres_fdw supports transactions across remote servers |
| **By default** | each remote statement runs in its own transaction |
| **Point 3** | You can control this with the fetch_size and other options |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Use Case: Cross-Server Partitioning
Another use case — data sharding. Split a large table across multiple servers and query them through foreign tables. You can even use table inheritance or partitioning to make this transparent.

```
[Application]
[Main PG (Router)]
[Shard 1: Users A-M]
[Shard 2: Users N-Z]
[Archive Server]
```

### Beginner Traps
Common beginner traps with postgres_fdw.

| The Mistake | The Fix |
| :--- | :--- |
| Forgetting pg_hba.conf on remote | Add host entry for the local server's IP |
| Not granting USAGE on foreign server | GRANT USAGE ON FOREIGN SERVER ... TO user |
| Large JOINs fetching full remote tables | Use materialized views for large joins |
| Using count(*) on huge remote tables | Push aggregates down or use EXPLAIN VERBOSE |
| Forgetting to set fetch_size | Set fetch_size to 1000+ for batch reads |


---

## 3. Hands-On Commands & psql Output

### Setup — Extension, Server, User Mapping
**Explanation:** Let us set up the complete connection. Step one — create the extension. Step two — define the foreign server with the remote host, port, and database. Step three — create a user mapping that maps your local user to a remote user with credentials.

```sql
postgres=# -- Step 1: Enable postgres_fdw:
postgres=# CREATE EXTENSION postgres_fdw;
postgres=# -- Step 2: Define the remote server:
postgres=# CREATE SERVER app_server
    FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (
        host '10.0.1.10',
        port '5432',
        dbname 'app_db'
    );
postgres=# -- Step 3: Map local user to remote credentials:
postgres=# CREATE USER MAPPING FOR analytics_user
    SERVER app_server
    OPTIONS (
        user 'readonly_user',
        password 'SecurePass123!'
    );
```

### Create Foreign Tables
**Explanation:** Step four — create foreign tables. You can define them manually or use IMPORT FOREIGN SCHEMA to auto-create them. Let us do both.

```sql
postgres=# -- Manual: define each column:
postgres=# CREATE FOREIGN TABLE remote_users (
    id int,
    name text,
    email text,
    created_at timestamptz
)
SERVER app_server
OPTIONS (schema_name 'public', table_name 'users');
postgres=# -- Or auto-import entire schema:
postgres=# CREATE SCHEMA IF NOT EXISTS app_data;
IMPORT FOREIGN SCHEMA public
postgres-# LIMIT TO (users, orders, products)
postgres-# FROM SERVER app_server
    INTO app_data;
postgres=# -- Now query:
postgres=# SELECT count(*) FROM app_data.users;
postgres=# SELECT count(*) FROM app_data.orders;
```

### Joining Remote and Local Tables
**Explanation:** Now the power of postgres_fdw — you can join remote tables with local tables. PostgreSQL is smart enough to push WHERE conditions and even joins between remote tables down to the remote server.

```sql
postgres=# -- Local analytics table:
postgres=# CREATE TABLE revenue_targets (
    user_id int PRIMARY KEY,
    target_amount numeric,
    quarter text
);
postgres=# -- Join remote users with local targets:
SELECT
    u.name,
    u.email,
    r.target_amount,
    r.quarter
postgres-# FROM app_data.users u
postgres-# JOIN revenue_targets r ON r.user_id = u.id
postgres-# WHERE r.quarter = '2024-Q4';
postgres=# -- Join two remote tables (pushed to remote!):
postgres=# SELECT u.name, count(o.id) AS order_count
postgres-# FROM app_data.users u
postgres-# JOIN app_data.orders o ON o.user_id = u.id
postgres-# GROUP BY u.name
postgres-# ORDER BY order_count DESC;
```

### What Gets Pushed Down?
**Explanation:** postgres_fdw pushes down many operations to the remote server. WHERE clauses, ORDER BY, LIMIT, aggregate functions like COUNT and SUM, and joins between tables on the same remote server are all pushed down. This means less data travels over the network.

```sql
postgres=# -- Check pushdown with EXPLAIN VERBOSE:
postgres=# EXPLAIN VERBOSE
postgres=# SELECT name, email
postgres-# FROM app_data.users
postgres-# WHERE created_at > '2024-01-01'
postgres-# ORDER BY name
postgres-# LIMIT 10;
                    QUERY PLAN
postgres=# --------------------------------------------------
 Foreign Scan on app_data.users
   Output: name, email
   Remote SQL:
postgres=# SELECT name, email FROM public.users
postgres-# WHERE (created_at > '2024-01-01'::timestamptz)
postgres-# ORDER BY name ASC NULLS LAST
postgres-# LIMIT 10::bigint
postgres=# -- ✓ WHERE, ORDER BY, LIMIT all pushed to remote
postgres=# -- Aggregate pushdown:
postgres=# EXPLAIN VERBOSE
postgres=# SELECT count(*) FROM app_data.orders;
postgres=# -- Remote SQL: SELECT count(*) FROM public.orders
```

### Writing to Remote Tables
**Explanation:** Unlike file_fdw, postgres_fdw supports writing to remote tables. You can INSERT, UPDATE, and DELETE on foreign tables. The changes happen on the remote server immediately.

```sql
postgres=# -- INSERT into remote table:
postgres=# INSERT INTO app_data.users (name, email)
postgres-# VALUES ('New User', 'new@example.com');
postgres=# -- UPDATE remote data:
postgres=# UPDATE app_data.users
postgres=# SET name = 'Updated Name'
postgres-# WHERE id = 100;
postgres=# -- DELETE from remote:
postgres=# DELETE FROM app_data.users
postgres-# WHERE id = 100;
postgres=# -- COPY from local to remote:
postgres=# INSERT INTO app_data.users (name, email)
postgres=# SELECT name, email
postgres-# FROM local_import_staging;
postgres=# -- Note: remote user must have INSERT/UPDATE/DELETE
postgres=# -- privileges on the target table
```

### Tuning fetch_size
**Explanation:** The fetch_size option is important for performance. By default, postgres_fdw fetches 100 rows at a time from the remote server using a cursor. For large result sets, increase this to reduce round-trips. For small result sets, decrease it to save memory.

```sql
postgres=# -- Set fetch_size on the server (applies to all tables):
postgres=# ALTER SERVER app_server
    OPTIONS (SET fetch_size '1000');
postgres=# -- Or set per table (overrides server setting):
postgres=# ALTER FOREIGN TABLE app_data.orders
    OPTIONS (SET fetch_size '5000');
postgres=# -- For large batch reads:
postgres=# ALTER FOREIGN TABLE app_data.orders
    OPTIONS (SET fetch_size '10000');
postgres=# -- Check current settings:
postgres=# SELECT ft.ftrelid::regclass, ftoptions
postgres-# FROM pg_foreign_table ft;
postgres=# -- Guidelines:
postgres=# --   Small lookups: 100 (default)
postgres=# --   Medium queries: 1000-5000
postgres=# --   Large batch reads: 10000+
```

### Use Case: Cross-Database Reporting
**Explanation:** Let us look at a real-world use case — cross-database reporting. Your application database has operational data. Your analytics database needs to pull reports from it without ETL pipelines.

```sql
postgres=# -- Analytics database pulls from app database:
postgres=# CREATE MATERIALIZED VIEW daily_revenue AS
SELECT
    date_trunc('day', o.created_at) AS day,
    count(*) AS order_count,
    sum(o.total_amount) AS revenue
postgres-# FROM app_data.orders o
postgres-# WHERE o.created_at >= current_date - interval '90 days'
postgres-# GROUP BY 1
postgres-# ORDER BY 1;
postgres=# -- Refresh daily:
REFRESH MATERIALIZED VIEW daily_revenue;
postgres=# -- Query locally (fast, no remote calls):
postgres=# SELECT day, revenue FROM daily_revenue
postgres-# WHERE day >= current_date - interval '7 days'
postgres-# ORDER BY day;
```

### Security Best Practices
**Explanation:** Security best practices for postgres_fdw. Always create a dedicated read-only user on the remote server. Use password files or environment variables instead of storing passwords in user mappings. Restrict which users can access the foreign server.

```sql
postgres=# -- On REMOTE server: create a restricted user:
postgres=# -- CREATE ROLE fdw_reader LOGIN PASSWORD 'SecurePass';
postgres=# -- GRANT CONNECT ON DATABASE app_db TO fdw_reader;
postgres=# -- GRANT USAGE ON SCHEMA public TO fdw_reader;
postgres=# -- GRANT SELECT ON ALL TABLES IN SCHEMA public
postgres=# --     TO fdw_reader;
postgres=# -- ALTER DEFAULT PRIVILEGES IN SCHEMA public
postgres=# --     GRANT SELECT ON TABLES TO fdw_reader;
postgres=# -- On LOCAL server: restrict server access:
postgres=# GRANT USAGE ON FOREIGN SERVER app_server
    TO analytics_user;
postgres=# -- Only analytics_user can use this server
postgres=# -- Use .pgpass file instead of password in mapping:
postgres=# -- ~/.pgpass format:
postgres=# -- 10.0.1.10:5432:app_db:fdw_reader:SecurePass
postgres=# -- Then create mapping without password:
postgres=# CREATE USER MAPPING FOR analytics_user
    SERVER app_server
    OPTIONS (user 'fdw_reader');
postgres=# -- Password read from .pgpass automatically
```

### Monitoring FDW Connections
**Explanation:** You can monitor active connections from postgres_fdw. When keep_connections is on, the FDW reuses connections to the remote server. You can see and disconnect them.

```sql
postgres=# -- See all cached FDW connections:
postgres=# SELECT server_name, valid, used_in_xact
postgres-# FROM postgres_fdw_get_connections();
 server_name | valid | used_in_xact
postgres=# -------------+-------+--------------
 app_server  | t     | f
postgres=# -- Disconnect cached connections:
postgres=# SELECT postgres_fdw_disconnect('app_server');
postgres=# -- true
postgres=# -- Disconnect ALL cached connections:
postgres=# SELECT postgres_fdw_disconnect_all();
postgres=# -- On REMOTE server, see incoming FDW connections:
postgres=# SELECT pid, usename, client_addr, application_name
postgres-# FROM pg_stat_activity
postgres-# WHERE usename = 'fdw_reader';
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Common beginner traps with postgres_fdw.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. postgres_fdw connects PostgreSQL to PostgreSQL with full read-write support. Set it up in four steps: extension, server, user mapping, foreign tables. Use IMPORT FOREIGN SCHEMA to auto-create tables. WHERE, ORDER BY, LIMIT, aggregates, and remote-to-remote joins are pushed down. Tune fetch_size for performance. Use materialized views for heavy reporting. Always use a restricted remote user and pgpass for passwords. In the next class, we explore table inheritance.

- **Connects PostgreSQL → PostgreSQL (read + write)**
- **Setup: extension → server → user mapping → tables**
- **IMPORT FOREIGN SCHEMA: auto-create from remote**
- **Pushdown: WHERE, ORDER BY, LIMIT, aggregates, joins**
- **EXPLAIN VERBOSE: shows Remote SQL being sent**
- **fetch_size: tune for query size (default 100)**
- **Materialized views: cache remote data locally**
- **Security: restricted remote user + .pgpass**
- **keep_connections: reuses connections (default on)**
- **postgres_fdw_get_connections(): monitor connections**
- **Next: Table Inheritance**


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
