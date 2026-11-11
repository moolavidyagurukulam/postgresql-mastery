# Schemas
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 10
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In our last class, we learned how to create and manage databases. Today we learn about schemas ... namespaces inside a database. ... Schemas help you organize your tables, views, and functions into logical groups. Think of them like folders on your computer. Without schemas, everything is in one big pile. With schemas, everything is neatly organized. ... Let us dive in!

### The Problem: One Big Pile of Tables
Here is the problem. Imagine you have a large application with tables for sales, human resources, and inventory. If you put all 50 tables in one place, it becomes a mess. ... Which tables belong to sales? Which belong to HR? ... Also, what if two teams both want a table called users? In the same schema, you cannot have two tables with the same name. ... Schemas solve this. You create a sales schema, an hr schema, and an inventory schema. Each team gets their own namespace. They can even have tables with the same name ... sales.users and hr.users are completely separate.

- 50+ tables — which belong to Sales? HR? Inventory?
- Two teams want a table called 'users' — name clash!
- No organization = confusion as the app grows
- Schemas = namespaces (like folders for your tables)
- sales.users and hr.users can coexist
- Today: CREATE, USE, and MANAGE schemas


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: One Big Pile of Tables
Here is the problem. Imagine you have a large application with tables for sales, human resources, and inventory. If you put all 50 tables in one place, it becomes a mess. ... Which tables belong to sales? Which belong to HR? ... Also, what if two teams both want a table called users? In the same schema, you cannot have two tables with the same name. ... Schemas solve this. You create a sales schema, an hr schema, and an inventory schema. Each team gets their own namespace. They can even have tables with the same name ... sales.users and hr.users are completely separate.

- 50+ tables — which belong to Sales? HR? Inventory?
- Two teams want a table called 'users' — name clash!
- No organization = confusion as the app grows
- Schemas = namespaces (like folders for your tables)
- sales.users and hr.users can coexist
- Today: CREATE, USE, and MANAGE schemas

### What is a Schema?
A schema is a namespace inside a database. It is a container that holds tables, views, functions, sequences, and other objects. ... Every database has at least one schema called public. When you create a table without specifying a schema, it goes into the public schema. ... The hierarchy is: Cluster contains Databases. Databases contain Schemas. Schemas contain Tables and other objects. ... You can have many schemas in one database. Each schema is independent. Objects in different schemas can have the same name without conflict.

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
Important rules about search_path. ... The SET command changes the search_path for your current session only. When you disconnect and reconnect, it resets to the default. ... To make a permanent change for a specific database, use ALTER DATABASE. ALTER DATABASE practice SET search_path TO sales, public. This applies to all future connections to that database. ... To make it permanent for a specific user, use ALTER ROLE. ... The first schema in the search_path is also where new objects are created if you do not specify a schema.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Important rules about search_path |
| **Point 2** | The SET command changes the search_path for your current session only |
| **When you disconnect and reconnect** | it resets to the default |
| **Point 4** | To make a permanent change for a specific database, use ALTER DATABASE |
| **Point 5** | ALTER DATABASE practice SET search_path TO sales, public |
| **Point 6** | This applies to all future connections to that database |
| **To make it permanent for a specific user** | use ALTER ROLE |
| **Point 8** | The first schema in the search_path is also where new objects are created if you do not specify a schema |

### When to Use Schemas — Common Patterns
When should you use schemas? ... Use case 1 ... Organize by department. sales, hr, finance schemas keep tables separated by team. ... Use case 2 ... Multi-tenancy. Each customer gets their own schema. tenant_acme, tenant_globex. All have the same table structure but isolated data. ... Use case 3 ... Separate application layers. A public-facing API schema, an internal admin schema, and a reporting schema. ... Use case 4 ... Extensions. Many DBAs create an extensions schema to keep extension objects separate from application tables. ... Schemas are flexible. Use them whenever you need logical separation.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | When should you use schemas? |
| **Point 2** | Organize by department |
| **Point 3** | sales, hr, finance schemas keep tables separated by team |
| **Point 4** | Each customer gets their own schema |
| **Point 5** | tenant_acme, tenant_globex |
| **Point 6** | All have the same table structure but isolated data |
| **Point 7** | Separate application layers |
| **A public** | facing API schema, an internal admin schema, and a reporting schema |


---

## 3. Hands-On Commands & psql Output

### CREATE SCHEMA & Create Tables in Schemas
**Explanation:** Creating a schema is simple. CREATE SCHEMA followed by the name. ... Let me create three schemas for our example ... sales, hr, and inventory. ... Now I can create tables inside each schema by using the dot notation. sales dot orders creates an orders table in the sales schema. hr dot employees creates an employees table in the hr schema. ... Use backslash dn to list all schemas. Use backslash dt schema dot star to list tables in a specific schema.

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
**Explanation:** Now here is the key concept ... the search_path. ... When you write SELECT star FROM orders, how does PostgreSQL know which schema to look in? It uses the search_path. ... The search_path is a list of schemas that PostgreSQL searches in order. By default, it is dollar sign user comma public. This means PostgreSQL first looks for a schema with your username, then looks in the public schema. ... If your table is in the sales schema and sales is not in the search_path, you will get an error ... relation orders does not exist. ... You can change the search_path with the SET command.

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

### The public Schema — Security Tip
**Explanation:** The public schema is special. It exists in every new database by default. By default, ALL users can create objects in the public schema. This can be a security concern. ... In production, many teams revoke the CREATE privilege on the public schema. This forces everyone to use their designated schemas. ... REVOKE CREATE ON SCHEMA public FROM PUBLIC semicolon. The first PUBLIC is the schema name. The second PUBLIC means all users. ... You can also drop the public schema entirely if you do not need it. But be careful ... some extensions expect it to exist.

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
**Explanation:** Let me show you more schema operations. ... To rename a schema, use ALTER SCHEMA. ... To change the owner of a schema, use ALTER SCHEMA with OWNER TO. ... To drop a schema, use DROP SCHEMA. But if the schema has objects inside it, you need CASCADE. DROP SCHEMA hr CASCADE drops the schema and everything inside it ... tables, views, functions, everything. This is dangerous. Use it carefully. ... DROP SCHEMA hr RESTRICT is the default and only drops the schema if it is empty.

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
**Explanation:** You can move objects between schemas. ... ALTER TABLE public dot users SET SCHEMA hr moves the users table from public to the hr schema. ... This is very useful when refactoring. You might start with everything in public and then organize into schemas as the application grows. ... After moving, any queries using the old schema-qualified name will break. Make sure to update your application code or adjust the search_path.

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
**Explanation:** Common schema errors. ... Error 1 ... relation does not exist. This is the most common. Your table exists but is not in the search_path. Either use the full name like sales dot orders, or add the schema to search_path. ... Error 2 ... schema already exists. You tried to create a schema that exists. Use CREATE SCHEMA IF NOT EXISTS. ... Error 3 ... cannot drop schema because other objects depend on it. The schema is not empty. Use CASCADE to drop everything, or drop the objects first.

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
Common schema errors. ... Error 1 ... relation does not exist. This is the most common. Your table exists but is not in the search_path. Either use the full name like sales dot orders, or add the schema to search_path. ... Error 2 ... schema already exists. You tried to create a schema that exists. Use CREATE SCHEMA IF NOT EXISTS. ... Error 3 ... cannot drop schema because other objects depend on it. The schema is not empty. Use CASCADE to drop everything, or drop the objects first.

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

Practice time! ... Exercise 1 ... Create three schemas: app, analytics, and staging. List them with backslash dn. ... Exercise 2 ... Create a table called app dot customers with id, name, and email. Insert 2 rows. Query with the full schema name. ... Exercise 3 ... Change the search_path to app, public. Now query customers without the schema prefix. ... Exercise 4 ... Move the customers table from app to analytics. Verify with backslash dt analytics dot star. ... Exercise 5 ... Drop all three schemas with CASCADE. Verify they are gone.

1. Exercise 1: CREATE SCHEMA app, analytics, staging → \dn
2. Exercise 2: CREATE TABLE app.customers → INSERT 2 rows → query
3. Exercise 3: SET search_path TO app, public → SELECT * FROM customers
4. Exercise 4: ALTER TABLE app.customers SET SCHEMA analytics → verify
5. Exercise 5: DROP SCHEMA app, analytics, staging CASCADE → \dn


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... A schema is a namespace inside a database. It organizes tables and other objects into logical groups. ... Every database has a public schema by default. ... CREATE SCHEMA name creates a new schema. Use schema dot table to reference objects. ... search_path controls which schemas PostgreSQL searches. SET for session, ALTER DATABASE for permanent. ... DROP SCHEMA CASCADE drops everything inside. Be very careful. ... Use schemas for department separation, multi-tenancy, and application layers. ... In our next class, we learn about tablespaces ... where data is physically stored on disk!

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
