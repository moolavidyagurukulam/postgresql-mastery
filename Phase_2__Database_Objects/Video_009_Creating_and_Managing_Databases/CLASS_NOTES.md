# Creating & Managing Databases
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 09
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We have officially completed Phase 1 Foundations, and today we begin Phase 2, Database Objects. Before you can create a single table, index, or user report, you must first build a home for that data. a PostgreSQL Database. Think of a company running an online store, an internal payroll tool, and a staging environment for testing. In this class, you will learn how to create databases safely with proper encoding, when to separate databases versus schemas, how to clone databases cleanly, how to modify settings with ALTER DATABASE, and how to inspect sizes and drop databases without dangerous accidents. Let us dive in!

### The Problem: Where Does Your Data Live?
Imagine this real production scenario. You are building an e-commerce web app, an internal analytics dashboard, and a staging test suite. If a junior engineer runs everything inside the default postgres database, one accidental DROP TABLE in staging can wipe live customer orders, and backing up just the analytics data becomes a four-hour nightmare. Separate databases keep each environment isolated. Today we answer every practical question: how to create a database, which options actually matter, when to alter or drop one, and when NOT to split into separate databases. Remember, isolating apps by database also lets you set separate connection limits, separate locale rules, and clean independent pg_dump backup schedules without touching live customer databases.

- Real Problem: Web app, analytics, and test sharing one DB = high blast radius
- Disaster: One test DROP or heavy report locks production orders
- Solution: Separate databases isolate data, security, and backups
- Key Questions: Which options (encoding, owner, template) should you set?
- Important Check: Can you JOIN across two PostgreSQL databases? (Spoiler: No!)
- Today: Master CREATE, ALTER, DROP DATABASE & template1 vs template0

### Why Separate Databases?
Think of a PostgreSQL server cluster like an apartment building, and each database like a locked apartment unit. They share the same building infrastructure, memory, and background processes, but inside each unit everything is isolated. Tables in your shop database CANNOT directly join against tables in your analytics database. Use separate databases for completely independent apps, separate client environments, or dev versus staging setups. When should you NOT use separate databases? If your tables need to join with each other inside one app, put them in separate schemas inside ONE database instead. Always keep that clean boundary in mind: multiple schemas inside one database share tables via JOINs effortlessly, whereas multiple separate databases give hard isolation for independent microservices, SaaS tenants, or staging clones.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Where Does Your Data Live?
Imagine this real production scenario. You are building an e-commerce web app, an internal analytics dashboard, and a staging test suite. If a junior engineer runs everything inside the default postgres database, one accidental DROP TABLE in staging can wipe live customer orders, and backing up just the analytics data becomes a four-hour nightmare. Separate databases keep each environment isolated. Today we answer every practical question: how to create a database, which options actually matter, when to alter or drop one, and when NOT to split into separate databases. Remember, isolating apps by database also lets you set separate connection limits, separate locale rules, and clean independent pg_dump backup schedules without touching live customer databases.

- Real Problem: Web app, analytics, and test sharing one DB = high blast radius
- Disaster: One test DROP or heavy report locks production orders
- Solution: Separate databases isolate data, security, and backups
- Key Questions: Which options (encoding, owner, template) should you set?
- Important Check: Can you JOIN across two PostgreSQL databases? (Spoiler: No!)
- Today: Master CREATE, ALTER, DROP DATABASE & template1 vs template0

### Why Separate Databases?
Think of a PostgreSQL server cluster like an apartment building, and each database like a locked apartment unit. They share the same building infrastructure, memory, and background processes, but inside each unit everything is isolated. Tables in your shop database CANNOT directly join against tables in your analytics database. Use separate databases for completely independent apps, separate client environments, or dev versus staging setups. When should you NOT use separate databases? If your tables need to join with each other inside one app, put them in separate schemas inside ONE database instead. Always keep that clean boundary in mind: multiple schemas inside one database share tables via JOINs effortlessly, whereas multiple separate databases give hard isolation for independent microservices, SaaS tenants, or staging clones.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Analogy** | Cluster = apartment building; each Database = locked apartment unit |
| **Isolation** | Tables in one DB cannot directly query or JOIN another DB |
| **Security** | Each DB has independent permissions, users, and search paths |
| **Backups** | Back up and restore one application without touching others |
| **When NOT** | Need cross-table JOINs? Use Schemas in one DB instead |

**Notes:**
- One PostgreSQL cluster → many isolated databases

### Default Databases — Created on Install
Right after you install PostgreSQL, three databases already exist out of the box. Think of them like empty rooms ready on move-in day. First is postgres, the default administrative database where psql and tools connect before you create your own databases. Second is template1, the living blueprint PostgreSQL copies every time you run CREATE DATABASE. Anything custom you install into template1, such as an audit table or helper extension, automatically appears in every brand-new database. Third is template0, the untouched, read-only factory backup template. Use template0 whenever you want a guaranteed clean slate or a different UTF-8 locale and encoding during database creation or restore.

| Term | Meaning / Explanation |
| :--- | :--- |
| **postgres** | Default admin database — your landing spot on first connect |
| **template1** | Default blueprint copied by CREATE DATABASE (modifiable) |
| **template0** | Read-only clean factory blueprint (safe for clean restores) |
| **Pro Tip** | Install common extensions in template1 so all new DBs inherit them |

### CREATE DATABASE Options Reference
Save this CREATE DATABASE reference card before we look at architectural trade-offs and cloning. Use OWNER to assign least-privilege application ownership from day one. Always use ENCODING UTF8, changing encoding after creation is NOT allowed in PostgreSQL without dumping and recreating the database. Choose template1 when you want shared extensions or helper functions pre-installed, or template0 whenever you set custom encoding or locale. Lock LC_COLLATE and LC_CTYPE carefully during creation, set CONNECTION LIMIT cleanly instead of leaving minus one unlimited on shared clusters, and optionally pass TABLESPACE to place heavy database files onto a dedicated NVMe or SSD drive.

| Term | Meaning / Explanation |
| :--- | :--- |
| **OWNER** | Sets DB owner role (never run apps as superuser postgres) |
| **ENCODING** | Character set — always choose 'UTF8' for modern apps |
| **TEMPLATE** | template1 (default) or template0 (clean factory slate) |
| **LOCALE** | LC_COLLATE (sort order) & LC_CTYPE (character rules) — locked! |
| **CONN LIMIT** | Max concurrent sessions (-1 = unlimited; e.g. 100 for app DB) |
| **TABLESPACE** | Optional disk location where new objects are stored |

### Where & When: Separate Database vs Schema
Here is a critical design question every developer and DBA asks early on: when should you create a brand-new database versus adding a new schema inside the same database?. Create a separate database when applications are truly independent, for example, your e-commerce store and your internal HR payroll tool, or staging and production on a test machine. Separate databases give you complete data, permission, and backup isolation, dropping test_db never risks production orders. On the other hand, do NOT create separate databases if your modules need SQL JOIN queries between each other! PostgreSQL forbids direct cross-database JOINs. Whenever analytics or billing needs to join across users and orders, keep them as separate schemas inside ONE database.

| Create a Separate Database When | Use Schemas in ONE Database When |
| :--- | :--- |
| Completely separate apps (Shop vs Payroll) | Modules belong to the same application |
| Need isolated backups & point-in-time restores | Reports need SQL JOINs across modules |
| Strict staging / QA / dev isolation | Shared users & single connection pool (PgBouncer) |
| Different connection limits or timezones | Multi-tenant SaaS with hundreds of tenants |
| Zero need to JOIN tables between apps | Saves server RAM & connection overhead |

### template1 vs template0
Let us talk more about templates. When you run CREATE DATABASE, PostgreSQL copies template1 to make the new database. If you add tables, functions, or extensions to template1, every new database will have them. This is useful. If every database needs the uuid-ossp extension, add it to template1 once. All future databases get it automatically. But be careful. Changes to template1 affect ALL future databases, not existing ones. template0 is the fallback clean template. Use it when you need a database with a different encoding than the cluster default, or when restoring a dump that needs a clean slate. In team environments, documenting exactly which extensions or standard helper schemas live inside template1 saves huge onboarding time, while keeping template0 untouched guarantees a clean restore target for pg_restore.

| template1 | template0 |
| :--- | :--- |
| Default template for new databases | Clean, unmodified template |
| CAN be modified | CANNOT be modified (read-only) |
| Add extensions → all new DBs get them | Used for: clean restores from backup |
| Add functions → all new DBs get them | Used for: different encoding than default |
| Use for: standard setup across databases | Safety net — always has a pristine copy |


---

## 3. Hands-On Commands & psql Output

### CREATE DATABASE — The Basics
**Explanation:** Creating a database is surprisingly clean in PostgreSQL. You run CREATE DATABASE followed by your database name and a semicolon. When we run CREATE DATABASE myapp, PostgreSQL copies the default template1 database, applies UTF-8 character encoding, sets you as the owner, and registers the new database inside the system catalog. Right afterward, run backslash l inside psql to inspect every database in your cluster. Look at the output columns in PostgreSQL 16: Name, Owner, Encoding, and Locale Provider. Notice myapp sits right beside postgres, template0, and template1. Now connect inside myapp with backslash c myapp, notice your psql prompt immediately changes from postgres=# to myapp=#, confirming you are working inside myapp!

```sql
-- Create a simple database
postgres=# CREATE DATABASE myapp;
CREATE DATABASE

-- Verify: list all databases
postgres=# \l
   Name    |  Owner   | Encoding | Locale Provider
-----------+----------+----------+-----------------
 myapp     | postgres | UTF8     | libc
 postgres  | postgres | UTF8     | libc
 template0 | postgres | UTF8     | libc
 template1 | postgres | UTF8     | libc

-- Connect to the new database
postgres=# \c myapp
You are now connected to database "myapp" as user "postgres".
```

### CREATE DATABASE with Options
**Explanation:** In real production deployments, experienced DBAs rarely run bare CREATE DATABASE, they specify explicit options for safety and international text support. First, OWNER sets which application role owns the database so your web app never runs as the postgres superuser. Second, ENCODING sets the character set, always choose UTF8 so emojis, Hindi, Arabic, European accents, and symbols all store accurately without corruption. Third, LC_COLLATE controls alphabetical sorting order, and LC_CTYPE defines uppercase and lowercase letter rules. Fourth, TEMPLATE specifies whether to copy template1 or clean factory template0. Fifth, CONNECTION LIMIT caps simultaneous connections, for example 100, so one buggy microservice cannot exhaust the entire server's connection pool.

```sql
-- Full syntax with options
postgres=# CREATE DATABASE shop
postgres-#   OWNER = postgres
postgres-#   ENCODING = 'UTF8'
postgres-#   LC_COLLATE = 'en_US.UTF-8'
postgres-#   LC_CTYPE = 'en_US.UTF-8'
postgres-#   TEMPLATE = template0
postgres-#   CONNECTION LIMIT = 100;
CREATE DATABASE

-- Create DB with a different owner
postgres=# CREATE ROLE webapp LOGIN PASSWORD 'secure123';
CREATE ROLE
postgres=# CREATE DATABASE webapp_db OWNER webapp;
CREATE DATABASE
```

### ALTER DATABASE — Modify After Creation
**Explanation:** After creating a database, you can modify it with ALTER DATABASE. You can rename it. ALTER DATABASE myapp RENAME TO myapp_v2. You can change the owner. ALTER DATABASE myapp_v2 OWNER TO webapp. You can set configuration parameters for that database. ALTER DATABASE myapp_v2 SET timezone TO Asia slash Kolkata. This setting applies only to connections to this database. You can also change the connection limit. ALTER DATABASE myapp_v2 CONNECTION LIMIT 50. One important thing. you CANNOT change the encoding or locale after creation. Those are set forever when you create the database. Whenever you run ALTER DATABASE SET maintenance_work_mem or timezone, remember that new parameter takes effect cleanly for future connections to that database without needing a server restart or touching sibling databases.

```sql
-- Rename a database
postgres=# ALTER DATABASE myapp RENAME TO myapp_v2;
ALTER DATABASE

-- Change owner
postgres=# ALTER DATABASE myapp_v2 OWNER TO webapp;
ALTER DATABASE

-- Set a config parameter for this database only
postgres=# ALTER DATABASE myapp_v2 SET timezone TO 'Asia/Kolkata';
ALTER DATABASE

-- Change connection limit
postgres=# ALTER DATABASE myapp_v2 CONNECTION LIMIT 50;
ALTER DATABASE

-- CANNOT change encoding or locale after creation!
```

### Cloning a Database & Locking Public Access
**Explanation:** Let us look at two real-world DBA superpowers every team uses in production: locking down database connections and cloning a database!. By default in PostgreSQL, ANY role on the cluster can attempt to connect to a new database. On multi-app servers, run REVOKE CONNECT ON DATABASE myapp_v2 FROM PUBLIC, followed by GRANT CONNECT ONLY to your specific application role!. Second, suppose a QA engineer asks for a fresh copy of myapp_v2 to test a risky migration. You do NOT need pg_dump for small local clones! Simply make sure nobody is connected to myapp_v2, and run CREATE DATABASE myapp_staging WITH TEMPLATE myapp_v2 OWNER webapp. PostgreSQL copies the entire database structure and rows at disk level in seconds, just remember to close active sessions on the source database first, or PostgreSQL safely blocks the clone.

```sql
-- Lock down database so only webapp role can connect
postgres=# REVOKE CONNECT ON DATABASE myapp_v2 FROM PUBLIC;
REVOKE
postgres=# GRANT CONNECT ON DATABASE myapp_v2 TO webapp;
GRANT

-- Clone an existing DB cleanly into staging (no active sessions!)
postgres=# CREATE DATABASE myapp_staging WITH TEMPLATE myapp_v2 OWNER webapp;
CREATE DATABASE

-- Note: If anyone is connected to myapp_v2, clone throws an error:
ERROR: source database "myapp_v2" is being accessed by other users
```

### DROP DATABASE — Delete Permanently
**Explanation:** To delete a database, use DROP DATABASE. DROP DATABASE myapp_v2 semicolon. Gone. All tables, all data, all schemas. everything inside is permanently deleted. There is no undo. There is no recycle bin. Important. you cannot drop the database you are currently connected to. You must connect to a different database first. Also, you cannot drop a database if other users are connected to it. PostgreSQL will give you an error. You must disconnect them first. In PostgreSQL 13 and later, you can use DROP DATABASE WITH FORCE to automatically terminate all connections and drop the database.

```sql
-- Make sure you're NOT connected to the database you're dropping!
postgres=# \c postgres
You are now connected to database "postgres" as user "postgres".

-- Drop the database
postgres=# DROP DATABASE myapp_v2;
DROP DATABASE

-- Safer: only drop if it exists
postgres=# DROP DATABASE IF EXISTS myapp_v2;
NOTICE:  database "myapp_v2" does not exist, skipping

-- Force drop (terminates active connections) PG 13+
postgres=# DROP DATABASE shop WITH (FORCE);
DROP DATABASE
```

### Common Errors & Solutions
**Explanation:** Let me show you the most common errors you will encounter. Error 1. database already exists. If you try to create a database that already exists, PostgreSQL gives an error. Solution. use CREATE DATABASE IF NOT EXISTS, or drop the old one first. Actually, PostgreSQL does not support IF NOT EXISTS for CREATE DATABASE. You have to check manually or handle the error in a script. Error 2. cannot drop the currently open database. You are connected to the database you are trying to drop. Solution. switch to a different database first with backslash c postgres. Error 3. database is being accessed by other users. Someone else is connected. Solution. terminate their connections first, then drop.

```sql
-- ERROR: database already exists
postgres=# CREATE DATABASE practice;
ERROR:  database "practice" already exists

-- ERROR: cannot drop currently connected database
practice=# DROP DATABASE practice;
ERROR:  cannot drop the currently open database
-- FIX: \c postgres  then DROP DATABASE practice;

-- ERROR: other users are connected
postgres=# DROP DATABASE practice;
ERROR:  database "practice" is being accessed by other users

-- FIX: Terminate other connections first
postgres=# SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'practice' AND pid <> pg_backend_pid();
 pg_terminate_backend
----------------------
 t
```

### Useful Database Queries
**Explanation:** Finally, save these system catalog queries for your daily DBA monitoring toolkit. To measure exact disk usage for every database in human-readable units like kilobytes, megabytes, or gigabytes, combine pg_database with pg_database_size and pg_size_pretty, sorted largest first so you catch fast-growing or bloated databases before disk space runs out. To inspect who is connected right now, query pg_stat_activity filtering WHERE datname IS NOT NULL. It displays database name, username, client IP address, and session state such as active or idle. We will rely on these exact catalog views constantly during production troubleshooting later in the course.

```sql
-- Check size of each database
postgres=# SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size FROM pg_database ORDER BY pg_database_size(datname) DESC;
  datname  |  size
-----------+---------
 postgres  | 7533 kB
 practice  | 7533 kB
 template1 | 7385 kB
 template0 | 7385 kB

-- Who is connected to which database?
postgres=# SELECT datname, usename, client_addr, state FROM pg_stat_activity WHERE datname IS NOT NULL;
  datname  | usename  | client_addr | state
-----------+----------+-------------+--------
 postgres  | postgres |             | active
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Errors & Solutions
Let me show you the most common errors you will encounter. Error 1. database already exists. If you try to create a database that already exists, PostgreSQL gives an error. Solution. use CREATE DATABASE IF NOT EXISTS, or drop the old one first. Actually, PostgreSQL does not support IF NOT EXISTS for CREATE DATABASE. You have to check manually or handle the error in a script. Error 2. cannot drop the currently open database. You are connected to the database you are trying to drop. Solution. switch to a different database first with backslash c postgres. Error 3. database is being accessed by other users. Someone else is connected. Solution. terminate their connections first, then drop.

```sql
-- ERROR: database already exists
CREATE DATABASE practice;
ERROR:  database "practice" already exists

-- ERROR: cannot drop currently connected database
DROP DATABASE practice;
ERROR:  cannot drop the currently open database
-- FIX: \c postgres  then DROP DATABASE practice;

-- ERROR: other users are connected
DROP DATABASE practice;
ERROR:  database "practice" is being accessed by other users

-- FIX: Terminate other connections first
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'practice' AND pid <> pg_backend_pid();
 pg_terminate_backend
----------------------
 t
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Time to lock in what you learned with five hands-on exercises!. Exercise 1: Create a database named school, verify its Encoding and Owner with backslash l, and connect to it with backslash c school. Exercise 2: Create a dedicated role and an inventory database specifying OWNER, ENCODING UTF8, and CONNECTION LIMIT 50. Exercise 3: Rename school to school_v2 and update its connection limit to 20 using ALTER DATABASE. Exercise 4: Clone school_v2 into school_test using WITH TEMPLATE, then query pg_database_size across all databases. Exercise 5: Connect back to postgres and clean up cleanly using DROP DATABASE IF EXISTS! Do not rush past Exercise 5: practicing pg_terminate_backend and template creation safely inside a local lab builds confidence before you ever run DROP DATABASE on a real staging or production server.

1. Exercise 1: CREATE DATABASE school → \l → \c school
2. Exercise 2: CREATE DATABASE inventory with OWNER, ENCODING, CONNECTION LIMIT
3. Exercise 3: ALTER DATABASE school RENAME TO school_v2, set limit to 20
4. Exercise 4: Query pg_database_size for all databases
5. Exercise 5: DROP DATABASE IF EXISTS school_v2; DROP DATABASE IF EXISTS inventory;


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. CREATE DATABASE creates a new database. Always specify ENCODING UTF8. Use TEMPLATE template0 for a clean start. ALTER DATABASE modifies an existing database. rename, change owner, set parameters. You CANNOT change encoding after creation. DROP DATABASE permanently deletes a database. No undo! Cannot drop the database you are connected to. Disconnect other users first. Three default databases: postgres for admin, template1 for the template, template0 for the clean fallback. In our next class, we learn about schemas. namespaces inside a database! Once you feel comfortable creating, altering, inspecting disk size, and safely dropping databases, every schema and table lesson ahead will fall right into place smoothly.

- **CREATE DATABASE name; — always use ENCODING 'UTF8'**
- **Options: OWNER, TEMPLATE, LC_COLLATE, CONNECTION LIMIT**
- **ALTER DATABASE: rename, change owner, set parameters**
- **Cannot change encoding/locale after creation**
- **DROP DATABASE: permanent! No undo, no recycle bin**
- **Cannot drop the DB you're connected to**
- **3 defaults: postgres, template1 (modifiable), template0 (clean)**


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
