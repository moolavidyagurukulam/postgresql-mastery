# Schemas
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 10
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In Class 9, we learned how to create and isolate complete databases. Now let us step one level deeper inside a database and master PostgreSQL Schemas!. Imagine growing a company app from 5 tables to 80 tables across Sales, HR, Billing, and Reporting. Without schemas, every single table gets dumped into one crowded folder with constant naming clashes. In this class, you will learn what schemas actually mean in PostgreSQL, how search_path resolves unqualified table names step by step, the crucial PostgreSQL 15 and 16 public schema security rule, moving objects, and when NOT to overuse schemas. Let us dive right in!

### The Problem: One Big Pile of Tables
Here is the problem. Imagine you have a large application with tables for sales, human resources, and inventory. If you put all 50 tables in one place, it becomes a mess. Which tables belong to sales? Which belong to HR?. Also, what if two teams both want a table called users? In the same schema, you cannot have two tables with the same name. Schemas solve this. You create a sales schema, an hr schema, and an inventory schema. Each team gets their own namespace. They can even have tables with the same name. sales.users and hr.users are completely separate. Before schemas existed cleanly in your workflow, teams either spun up dozens of wasteful databases or suffixed every table like sales_orders and hr_orders. Schemas organize everything cleanly under one roof with granular permissions.

- 50+ tables — which belong to Sales? HR? Inventory?
- Two teams want a table called 'users' — name clash!
- No organization = confusion as the app grows
- Schemas = namespaces (like folders for your tables)
- sales.users and hr.users can coexist
- Today: CREATE, USE, and MANAGE schemas


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: One Big Pile of Tables
Here is the problem. Imagine you have a large application with tables for sales, human resources, and inventory. If you put all 50 tables in one place, it becomes a mess. Which tables belong to sales? Which belong to HR?. Also, what if two teams both want a table called users? In the same schema, you cannot have two tables with the same name. Schemas solve this. You create a sales schema, an hr schema, and an inventory schema. Each team gets their own namespace. They can even have tables with the same name. sales.users and hr.users are completely separate. Before schemas existed cleanly in your workflow, teams either spun up dozens of wasteful databases or suffixed every table like sales_orders and hr_orders. Schemas organize everything cleanly under one roof with granular permissions.

- 50+ tables — which belong to Sales? HR? Inventory?
- Two teams want a table called 'users' — name clash!
- No organization = confusion as the app grows
- Schemas = namespaces (like folders for your tables)
- sales.users and hr.users can coexist
- Today: CREATE, USE, and MANAGE schemas

### Prerequisites & Where Schemas Fit
Before we run SQL commands, let us connect this cleanly to our last lesson on databases. Remember our building analogy: if each Database is a locked apartment unit completely isolated from other apartments, then Schemas are labeled rooms or filing cabinets inside that single apartment! Unlike separate databases, SQL queries inside one database can freely JOIN tables across different schemas in the very same query, for example joining sales dot orders with hr dot reps inside one clean SELECT. That makes schemas the ideal organizational layer whenever multiple modules or business teams share one PostgreSQL database.

- Completed: Cluster → Database → Schema → Table hierarchy (Class 05 & 09)
- Analogy: Database = Locked Apartment Unit | Schema = Labeled Room Folders inside
- Unlike Databases: Queries CAN freely JOIN tables across schemas (e.g. sales.orders JOIN hr.reps)
- Goal: Organize large apps cleanly without creating separate isolated databases

### What is a Schema?
So what is a schema in plain English? A schema is a named folder or namespace inside a single PostgreSQL database. It holds tables, views, functions, indexes, and sequences neatly together. Every new database starts with one built-in schema named public. Whenever you create a table without typing a schema prefix, PostgreSQL automatically places it inside public. Keep the PostgreSQL hierarchy clear: the Cluster holds Databases, each Database holds Schemas, and each Schema holds Tables and code objects. Best of all, two different schemas inside the same database can both have a table named orders without any conflict!

| Term | Meaning / Explanation |
| :--- | :--- |
| **What** | A container/namespace inside a database |
| **Holds** | Tables, views, functions, sequences, types |
| **Default** | Every database has a 'public' schema |
| **Hierarchy** | Cluster → Database → Schema → Tables |
| **Benefit** | Same-name objects can exist in different schemas |

**Notes:**
- Think of schemas like folders — they organize your database objects

### search_path Rules
Keep these five practical rules in mind whenever you work with search_path. First, running SET search_path changes the path only for your current connection; as soon as you disconnect, it resets. Second, use ALTER DATABASE to make a search_path permanent for every future connection to that database. Third, use ALTER ROLE when a specific service account, like a reporting user, needs its own schema lookup order. Fourth, PostgreSQL searches schemas from left to right and stops at the first matching table name. Fifth, when you create a table without writing a schema prefix, PostgreSQL puts it inside the very first schema listed in search_path.

| Term | Meaning / Explanation |
| :--- | :--- |
| **SET (Session)** | Temporary — resets as soon as your connection closes |
| **ALTER DB** | Permanent default for all connections to a specific database |
| **ALTER ROLE** | Permanent per-user setting (e.g., reporting user sees analytics) |
| **Left to Right** | PG checks schemas in order and picks the FIRST matching table |
| **New Objects** | Unqualified CREATE TABLE goes into the first schema in path |

### PostgreSQL 15 & 16 Security Change on public Schema!
Pay very close attention to this PostgreSQL 16 security rule that catches almost everyone coming from older tutorials!. Before PostgreSQL 15, any user who could connect to a database could automatically create tables in the public schema, which caused security risks like trojan object attacks. Starting in PostgreSQL 15 and PostgreSQL 16, CREATE on the public schema is revoked from PUBLIC by default! So if you create a regular non-superuser role today and it runs CREATE TABLE inside public, PostgreSQL throws ERROR: permission denied for schema public!. The clean modern fix is never letting apps share public directly: instead, give your app role its own owned schema using CREATE SCHEMA app AUTHORIZATION app_role.

> **Definition:** Since PostgreSQL 15+, regular users NO LONGER have CREATE permission on public by default!

| Term | Meaning / Explanation |
| :--- | :--- |
| **Old PG <= 14** | All database users (PUBLIC) could create tables in public automatically |
| **New PG 15 & 16** | PUBLIC CREATE was revoked — only DB owner / pg_database_owner can create |
| **Common Error** | Non-owner gets: ERROR: permission denied for schema public |
| **Best Fix** | Create dedicated app schema (CREATE SCHEMA app AUTHORIZATION app_role;) |

### When to Use Schemas — Common Patterns
Where and when should you actually create schemas in real projects?. Pattern one is department boundaries: separate sales, hr, and finance tables cleanly inside one company database so they can still join together. Pattern two is multi-tenant SaaS: give each B2B customer their own schema like tenant_acme and tenant_globex with identical tables and isolated rows, great for up to a few hundred tenants. Pattern three is application layers: expose safe views in an api schema while hiding raw tables inside an internal core schema. Pattern four is isolating extensions in an extensions schema. When NOT to use schemas? For tens of thousands of tenants, use a tenant_id column instead of 50,000 schemas.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Departments** | Group sales, hr, finance tables while still allowing SQL JOINs |
| **Multi-Tenant** | Give B2B clients tenant_acme, tenant_globex (<1,000 tenants) |
| **App Layers** | Expose views in api schema; lock raw tables in core schema |
| **Extensions** | Keep pg_stat_statements or extensions out of app schemas |
| **Avoid When** | 10,000+ tenants? Use a tenant_id column, not 10,000 schemas |


---

## 3. Hands-On Commands & psql Output

### CREATE SCHEMA & Create Tables in Schemas
**Explanation:** Creating schemas takes just two words: CREATE SCHEMA followed by the schema name. Here we create three clean namespaces inside our practice database: sales, hr, and inventory. Once created, you place tables inside a specific schema using dot notation: CREATE TABLE sales dot orders puts orders into sales, while CREATE TABLE hr dot employees puts employees into hr. You can even create both sales dot users and hr dot users simultaneously without any conflict!. Run backslash d n inside psql to list all schemas and their owners, or backslash d t sales dot star to list tables inside only the sales schema. Notice the AUTHORIZATION clause too: creating a schema owned by a dedicated team role gives that team clean DDL ownership right from the start without handing out dangerous superuser privileges.

```sql
-- Create schemas
practice=# CREATE SCHEMA sales;
CREATE SCHEMA
practice=# CREATE SCHEMA hr;
CREATE SCHEMA
practice=# CREATE SCHEMA inventory;
CREATE SCHEMA

-- Create tables INSIDE schemas (schema.table)
practice=# CREATE TABLE sales.orders (id SERIAL PRIMARY KEY, total NUMERIC(10,2));
CREATE TABLE
practice=# CREATE TABLE hr.employees (id SERIAL PRIMARY KEY, name VARCHAR(100));
CREATE TABLE

-- List schemas
practice=# \dn
   Name    |     Owner
-----------+-----------
 hr        | postgres
 inventory | postgres
 public    | pg_database_owner
 sales     | postgres
```

### search_path — How PostgreSQL Finds Your Tables
**Explanation:** Now here is the key concept. the search_path. When you write SELECT star FROM orders, how does PostgreSQL know which schema to look in? It uses the search_path. The search_path is a list of schemas that PostgreSQL searches in order. By default, it is dollar sign user comma public. This means PostgreSQL first looks for a schema with your username, then looks in the public schema. If your table is in the sales schema and sales is not in the search_path, you will get an error. relation orders does not exist. You can change the search_path with the SET command. Think of search_path just like your Windows PATH or Linux PATH variable. Whenever you omit the schema name, PostgreSQL walks that ordered comma-separated list from left to right and stops at the very first matching table.

```sql
-- Check current search_path
practice=# SHOW search_path;
   search_path
-----------------
 "$user", public

-- This FAILS: 'orders' is in sales schema, not in search_path
practice=# SELECT * FROM orders;
ERROR:  relation "orders" does not exist

-- Option 1: Use full qualified name
practice=# SELECT * FROM sales.orders;
(0 rows)

-- Option 2: Change search_path
practice=# SET search_path TO sales, public;
SET
practice=# SELECT * FROM orders;
(0 rows)
-- Now it works! PostgreSQL looks in 'sales' first
```

### Watch search_path Resolve Same-Name Tables Live!
**Explanation:** Let us watch how PostgreSQL's search_path behaves when two schemas hold identically named tables!. Suppose both sales dot users and hr dot users exist in the same database. When we run SET search_path TO hr, sales, public, and then execute SELECT star FROM users WITHOUT any schema prefix, PostgreSQL scans hr first, finds hr dot users, and immediately returns HR Manager, skipping sales dot users!. Even more importantly, look at the bottom: running an unqualified CREATE TABLE temp_notes places the new table inside hr because hr sits FIRST in search_path. Knowing this left-to-right rule avoids deploying tables into the wrong schema by mistake!

```sql
-- Two schemas both have a table named "users": sales.users & hr.users
practice=# CREATE TABLE sales.users (name TEXT); INSERT INTO sales.users VALUES ('Sales Admin');
practice=# CREATE TABLE hr.users (name TEXT);    INSERT INTO hr.users VALUES ('HR Manager');

-- search_path checks schemas LEFT to RIGHT and stops at FIRST match
practice=# SET search_path TO hr, sales, public;
practice=# SELECT * FROM users;
    name
------------
 HR Manager

-- Unqualified CREATE TABLE also goes into the FIRST schema (hr)!
practice=# CREATE TABLE temp_notes (note TEXT);
practice=# \dt temp_notes
 hr | temp_notes | table | postgres
```

### The public Schema — Security Tip
**Explanation:** The public schema is special. It exists in every new database by default. By default, ALL users can create objects in the public schema. This can be a security concern. In production, many teams revoke the CREATE privilege on the public schema. This forces everyone to use their designated schemas. REVOKE CREATE ON SCHEMA public FROM PUBLIC semicolon. The first PUBLIC is the schema name. The second PUBLIC means all users. You can also drop the public schema entirely if you do not need it. But be careful. some extensions expect it to exist. Remember why this matters for security audits: in legacy PostgreSQL 14, any database user could accidentally drop objects into public unless restricted, whereas PostgreSQL 15 and 16 lock CREATE down by default.

```sql
-- By default, everyone can create objects in public
-- This is a security risk in production!

-- Revoke CREATE on public schema from all users
practice=# REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE

-- Now only the owner can create objects in public
-- Everyone else must use their own schema

-- Grant usage on a specific schema to a role
practice=# GRANT USAGE ON SCHEMA sales TO webapp;
GRANT
practice=# GRANT ALL ON ALL TABLES IN SCHEMA sales TO webapp;
GRANT

-- Restore CREATE on public if needed
practice=# GRANT CREATE ON SCHEMA public TO PUBLIC;
GRANT
```

### ALTER & DROP Schema
**Explanation:** Now let us look at altering and removing schemas safely in daily DBA work. To rename an existing schema cleanly, use ALTER SCHEMA old_name RENAME TO new_name. Nobody loses any data. To transfer ownership to a team role or service account, run ALTER SCHEMA name OWNER TO new_owner. When it is time to delete a schema with DROP SCHEMA, PostgreSQL defaults to RESTRICT, meaning it refuses to drop the schema if even one table or view remains inside it. Only add CASCADE, like DROP SCHEMA hr CASCADE, when you intentionally want to wipe the schema and every table, view, and function inside it permanently.

```sql
-- Rename a schema
practice=# ALTER SCHEMA inventory RENAME TO warehouse;
ALTER SCHEMA

-- Change owner
practice=# ALTER SCHEMA warehouse OWNER TO postgres;
ALTER SCHEMA

-- Drop empty schema
practice=# DROP SCHEMA warehouse;
DROP SCHEMA

-- Drop schema WITH all objects inside (DANGEROUS!)
practice=# DROP SCHEMA hr CASCADE;
NOTICE:  drop cascades to table hr.employees
DROP SCHEMA

-- Safe: only drop if exists
practice=# DROP SCHEMA IF EXISTS hr;
NOTICE:  schema "hr" does not exist, skipping
```

### Moving Objects Between Schemas
**Explanation:** As applications grow, developers often start prototyping quickly inside the public schema, and months later the team decides to organize tables cleanly into domain schemas like app, billing, or analytics. Moving an existing table requires zero data export and zero downtime for copying rows: run ALTER TABLE public dot users SET SCHEMA app, and PostgreSQL updates its internal system catalog pointer immediately, keeping every row, index, and foreign key intact! Just remember one crucial DBA check afterward: any views, stored functions, or app SQL queries that hard-coded public dot users must be updated to app dot users or rely on an updated search_path.

```sql
-- Create a table in public schema
practice=# CREATE TABLE public.users (id SERIAL PRIMARY KEY, name VARCHAR(100));
CREATE TABLE

-- Create a target schema
practice=# CREATE SCHEMA app;
CREATE SCHEMA

-- Move table from public to app schema
practice=# ALTER TABLE public.users SET SCHEMA app;
ALTER TABLE

-- Verify: table is now in app schema
practice=# \dt app.*
       List of relations
 Schema | Name  | Type  | Owner
--------+-------+-------+----------
 app    | users | table | postgres
```

### Common Schema Errors
**Explanation:** Let us review the three schema errors every beginner sees so you recognize the fix immediately. Error one: relation does not exist. Almost always, your table really does exist inside another schema like sales or analytics, it is simply missing from your current search_path! Fix it either by schema-qualifying the name, sales dot orders, or adding sales to search_path. Error two: schema already exists. Avoid script failures during deployments by writing CREATE SCHEMA IF NOT EXISTS. Error three: cannot drop schema because other objects depend on it. That is PostgreSQL protecting you! Either drop the remaining tables manually first, or confirm and use CASCADE deliberately.

```sql
-- ERROR: relation does not exist
practice=# SELECT * FROM orders;
ERROR:  relation "orders" does not exist
-- FIX: SELECT * FROM sales.orders; OR SET search_path

-- ERROR: schema already exists
practice=# CREATE SCHEMA sales;
ERROR:  schema "sales" already exists
-- FIX: CREATE SCHEMA IF NOT EXISTS sales;

-- ERROR: cannot drop — objects depend on it
practice=# DROP SCHEMA sales;
ERROR:  cannot drop schema sales because other objects depend on it
DETAIL:  table sales.orders depends on schema sales
-- FIX: DROP SCHEMA sales CASCADE; (drops everything inside!)
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Schema Errors
Let us review the three schema errors every beginner sees so you recognize the fix immediately. Error one: relation does not exist. Almost always, your table really does exist inside another schema like sales or analytics, it is simply missing from your current search_path! Fix it either by schema-qualifying the name, sales dot orders, or adding sales to search_path. Error two: schema already exists. Avoid script failures during deployments by writing CREATE SCHEMA IF NOT EXISTS. Error three: cannot drop schema because other objects depend on it. That is PostgreSQL protecting you! Either drop the remaining tables manually first, or confirm and use CASCADE deliberately.

```sql
-- ERROR: relation does not exist
SELECT * FROM orders;
ERROR:  relation "orders" does not exist
-- FIX: SELECT * FROM sales.orders; OR SET search_path

-- ERROR: schema already exists
CREATE SCHEMA sales;
ERROR:  schema "sales" already exists
-- FIX: CREATE SCHEMA IF NOT EXISTS sales;

-- ERROR: cannot drop — objects depend on it
DROP SCHEMA sales;
ERROR:  cannot drop schema sales because other objects depend on it
DETAIL:  table sales.orders depends on schema sales
-- FIX: DROP SCHEMA sales CASCADE; (drops everything inside!)
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

Here are five practical hands-on exercises to cement schemas in memory before our next lesson! Exercise one: create three schemas named app, analytics, and staging, then list them with backslash dn. Exercise two: create app dot customers with id, name, and email, insert two sample rows, and query with the schema prefix. Exercise three: set search_path to app comma public, then select from customers without typing any prefix. Exercise four: move customers cleanly from app into analytics using ALTER TABLE SET SCHEMA, and verify with backslash dt analytics dot star. Exercise five: clean up all three schemas carefully with CASCADE and verify with backslash dn.

1. Exercise 1: CREATE SCHEMA app, analytics, staging → \dn
2. Exercise 2: CREATE TABLE app.customers → INSERT 2 rows → query
3. Exercise 3: SET search_path TO app, public → SELECT * FROM customers
4. Exercise 4: ALTER TABLE app.customers SET SCHEMA analytics → verify
5. Exercise 5: DROP SCHEMA app, analytics, staging CASCADE → \dn


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. A schema is a namespace inside a database. It organizes tables and other objects into logical groups. Every database has a public schema by default. CREATE SCHEMA name creates a new schema. Use schema dot table to reference objects. search_path controls which schemas PostgreSQL searches. SET for session, ALTER DATABASE for permanent. DROP SCHEMA CASCADE drops everything inside. Be very careful. Use schemas for department separation, multi-tenancy, and application layers. In our next class, we learn about tablespaces. where data is physically stored on disk! Keeping public clean and organizing application domains into schemas with a deliberate search_path is one of the highest-value habits any PostgreSQL engineer or DBA can build early.

- **Schema = namespace inside a database (like folders)**
- **Default: public schema in every database**
- **CREATE SCHEMA name; then CREATE TABLE schema.table**
- **search_path controls lookup order (SET or ALTER DATABASE)**
- **GRANT USAGE/ALL to control access per schema**
- **ALTER TABLE ... SET SCHEMA to move objects**
- **DROP SCHEMA name CASCADE; drops schema + all objects**


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


## Answer Key ? Schema Practice Solutions
1. **Create & List Schemas:** `CREATE SCHEMA app; CREATE SCHEMA analytics; CREATE SCHEMA staging;` then `\dn`.
2. **Create Table & Insert:** `CREATE TABLE app.customers (id SERIAL PRIMARY KEY, name TEXT, email TEXT);` ? `INSERT` 2 rows ? `SELECT * FROM app.customers;`.
3. **Use `search_path` Without Prefix:** `SET search_path TO app, public;` ? `SELECT * FROM customers;`.
4. **Move Table Between Schemas:** `ALTER TABLE app.customers SET SCHEMA analytics;` ? verify with `\dt analytics.*`.
5. **Drop Schemas Cleanly:** `DROP SCHEMA app, analytics, staging CASCADE;` ? verify with `\dn`.
