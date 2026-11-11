# Users, Roles & Privileges
**Series:** PostgreSQL Mastery | **Phase:** Phase 16: Administration Basics | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery! In this class, we cover users, roles, and privileges — the access control system of PostgreSQL. You will learn that in PostgreSQL, there is no difference between a user and a role — a user is just a role that can log in. We will build a complete privilege hierarchy: a read-only role, a read-write role, and an admin role. By the end, you will know exactly how to control who can access what in your database. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Role Hierarchy Design
Now let us build a complete role hierarchy for a real application. We create three group roles: reader for read-only access, writer for read-write access, and admin for full DDL access. Then we create individual user roles and grant them membership in the appropriate groups. This pattern means you manage permissions on the group, not on each individual user.

```
[admin
(group)]
[writer
(group)]
[reader
(group)]
[alice
(login)]
[bob
(login)]
[carol
(login)]
```

### INHERIT vs NOINHERIT
Role inheritance. When you grant role B to role A, does A automatically get B's privileges? It depends on the INHERIT option. By default, roles have INHERIT, which means they automatically get all privileges of their granted roles. With NOINHERIT, the user must explicitly SET ROLE to activate the group's privileges. NOINHERIT is a security feature — it prevents accidental use of elevated privileges. Think of it like sudo on Linux: you have admin access, but you must explicitly activate it.

| INHERIT (default) | NOINHERIT |
| :--- | :--- |
| Auto-gets group privileges | Must SET ROLE to activate |
| No SET ROLE needed | Explicit privilege escalation |
| Simpler to use | More secure (opt-in) |
| Less secure (always active) | Like sudo on Linux |
| Good for: reader, writer groups | Good for: admin, superuser |

### Schema Privileges — The Front Door Key
Schema-level privileges are a common source of confusion. Even if you GRANT SELECT on all tables, the user still needs USAGE on the schema to see those tables. Think of it like a building: USAGE is the key to the front door, and table privileges are keys to individual rooms. Without the front door key, you cannot reach any room.

- 1 -- Required to see and access objects in the schema. Like the building key.
- 2 -- Required to create new objects (tables, views, functions) in the schema.
- 3 -- SELECT, INSERT, UPDATE, DELETE — on specific tables within the schema.
- 4 -- GRANT SELECT ON ALL TABLES but forget GRANT USAGE ON SCHEMA → still denied!
- 5 -- GRANT USAGE ON SCHEMA public TO role; then GRANT SELECT ON ALL TABLES...

### Support & Materials
If you are enjoying this course, please consider supporting it. You can donate through PayPal or UPI — the links are in the description. Every contribution helps keep this course free and growing. You can also download the class materials from GitHub — the link is in the description too. Now let us continue with the decision framework.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Privilege Decision Framework
Here is the decision framework for privilege design. Follow these principles and you will avoid the most common security mistakes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is the decision framework for privilege design |
| **Point 2** | Follow these principles and you will avoid the most common security mistakes |

### Practice Exercises
Time to practice. First, create three group roles — reader, writer, admin — and three login users assigned to each. Second, grant appropriate table privileges to each group and test by connecting as each user. Third, create a new table and verify that reader can or cannot SELECT from it — then fix it with ALTER DEFAULT PRIVILEGES. Fourth, try to drop a role that owns objects and follow the three-step cleanup. Fifth, revoke CREATE on the public schema from PUBLIC.

- 1 -- 3 groups (NOLOGIN) + 3 users (LOGIN). GRANT group TO user.
- 2 -- GRANT SELECT to reader. SET ROLE user, try SELECT and INSERT.
- 3 -- Create table, test reader access, fix with ALTER DEFAULT PRIVILEGES.
- 4 -- REASSIGN OWNED BY → DROP OWNED BY → DROP ROLE
- 5 -- REVOKE CREATE ON SCHEMA public FROM PUBLIC;


---

## 3. Hands-On Commands & psql Output

### Roles vs Users — They Are the Same
**Explanation:** In PostgreSQL, everything is a role. CREATE USER is just a shorthand for CREATE ROLE with the LOGIN option. A role that can log in is a user. A role that cannot log in is a group. You can grant one role to another role — this is how you build a hierarchy. Let us see the difference.

```sql
postgres=# -- These two are IDENTICAL:
postgres=# CREATE USER alice WITH PASSWORD 'secure_pass_123';
CREATE ROLE
postgres=# CREATE ROLE bob WITH LOGIN PASSWORD 'secure_pass_456';
CREATE ROLE
postgres=# -- A group role (no LOGIN):
postgres=# CREATE ROLE readonly NOLOGIN;
CREATE ROLE
postgres=# \du
                              List of roles
 Role name |                   Attributes
-----------+-----------------------------------------------
 alice     |
 bob       |
 postgres  | Superuser, Create role, Create DB, Replication
 readonly  | Cannot login
```

### CREATE ROLE Options
**Explanation:** CREATE ROLE has many options. Let us look at the most important ones. LOGIN allows the role to connect. SUPERUSER gives unlimited access — use sparingly. CREATEDB allows creating databases. CREATEROLE allows creating other roles. CONNECTION LIMIT restricts how many simultaneous connections this role can have. VALID UNTIL sets a password expiration date. PASSWORD sets the login password. IN ROLE grants membership in another role immediately.

```sql
CREATE ROLE role_name WITH
    LOGIN                    -- can connect (= CREATE USER)
    PASSWORD 'secret'        -- set password
    SUPERUSER | NOSUPERUSER  -- unlimited access
    CREATEDB | NOCREATEDB    -- can create databases
    CREATEROLE | NOCREATEROLE -- can create roles
    INHERIT | NOINHERIT      -- auto-inherit granted role privileges
    CONNECTION LIMIT 5       -- max simultaneous connections
    VALID UNTIL '2027-01-01' -- password expiration
    IN ROLE group_role;      -- grant membership at creation

-- Modify later:
ALTER ROLE alice WITH CREATEDB;
ALTER ROLE alice SET work_mem = '128MB'; -- per-role default
ALTER ROLE alice RENAME TO alice_admin;
ALTER ROLE alice WITH PASSWORD 'new_pass';
```

### Building the Role Hierarchy
**Explanation:** Let us build this hierarchy step by step. First, we create the group roles without LOGIN — they are just permission containers. Then we create the user roles with LOGIN. Finally, we grant group membership to users. Alice gets writer, Bob gets admin, and Carol gets reader.

```sql
postgres=# -- Step 1: Create group roles (no login)
postgres=# CREATE ROLE reader NOLOGIN;
CREATE ROLE
postgres=# CREATE ROLE writer NOLOGIN;
CREATE ROLE
postgres=# CREATE ROLE admin_role NOLOGIN;
CREATE ROLE
postgres=# -- Step 2: Create login users
postgres=# CREATE ROLE alice LOGIN PASSWORD 'pass_alice';
CREATE ROLE
postgres=# CREATE ROLE bob LOGIN PASSWORD 'pass_bob';
CREATE ROLE
postgres=# CREATE ROLE carol LOGIN PASSWORD 'pass_carol';
CREATE ROLE
postgres=# -- Step 3: Grant group membership
postgres=# GRANT writer TO alice;
GRANT ROLE
postgres=# GRANT admin_role TO bob;
GRANT ROLE
postgres=# GRANT reader TO carol;
GRANT ROLE
```

### GRANT Syntax
**Explanation:** Now we grant actual privileges to the group roles. GRANT controls what operations a role can perform on database objects. The key privilege types are: SELECT for reading, INSERT for adding rows, UPDATE for changing rows, DELETE for removing rows, and ALL PRIVILEGES for everything. You grant on specific tables, all tables in a schema, or entire schemas and databases.

```sql
-- Table-level privileges:
GRANT SELECT ON table_name TO role_name;
GRANT INSERT, UPDATE, DELETE ON table_name TO role_name;
GRANT ALL PRIVILEGES ON table_name TO role_name;

-- All tables in a schema:
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;
GRANT SELECT, INSERT, UPDATE, DELETE
    ON ALL TABLES IN SCHEMA public TO writer;

-- Schema usage (required to see objects):
GRANT USAGE ON SCHEMA public TO reader;
GRANT USAGE, CREATE ON SCHEMA public TO admin_role;

-- Database-level:
GRANT CONNECT ON DATABASE myapp TO reader;
GRANT CREATE ON DATABASE myapp TO admin_role;

-- Sequences (needed for SERIAL/IDENTITY columns):
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO writer;
```

### Applying Privileges to Groups
**Explanation:** Let us apply privileges to our groups. Reader gets SELECT only. Writer gets SELECT, INSERT, UPDATE, DELETE. Admin gets everything plus DDL permissions. We also need to handle future tables — by default, GRANT only applies to existing tables. We use ALTER DEFAULT PRIVILEGES to automatically grant permissions on tables created in the future.

```sql
postgres=# \c trigger_lab
You are now connected to database "trigger_lab".
trigger_lab=# -- Reader: SELECT only
trigger_lab=# GRANT USAGE ON SCHEMA public TO reader;
GRANT
trigger_lab=# GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;
GRANT
trigger_lab=# -- Writer: read + write + sequences
trigger_lab=# GRANT USAGE ON SCHEMA public TO writer;
GRANT
trigger_lab=# GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO writer;
GRANT
trigger_lab=# GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO writer;
GRANT
trigger_lab=# -- FUTURE tables automatically get same grants:
trigger_lab=# ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO reader;
ALTER DEFAULT PRIVILEGES
trigger_lab=# ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO writer;
ALTER DEFAULT PRIVILEGES
```

### Testing Permissions
**Explanation:** Let us test the permissions. We connect as Carol, who is a member of the reader group, and try to SELECT and INSERT. SELECT should work. INSERT should be denied.

```sql
trigger_lab=# SET ROLE carol;
SET
trigger_lab=> SELECT name, salary FROM employees LIMIT 2;
  name  |  salary
--------+----------
  Alice | 90000.00
  Bob   | 75000.00
(2 rows)
trigger_lab=> INSERT INTO employees (name, department, salary) VALUES ('Test', 'HR', 50000);
ERROR:  permission denied for table employees
trigger_lab=> RESET ROLE;
RESET
trigger_lab=# SET ROLE alice;
SET
trigger_lab=> INSERT INTO employees (name, department, salary) VALUES ('Test', 'HR', 50000);
INSERT 0 1
-- -- Alice (writer) can INSERT. Carol (reader) cannot.
```

### REVOKE — Removing Privileges
**Explanation:** REVOKE removes privileges. The syntax mirrors GRANT. You can revoke specific privileges or ALL PRIVILEGES. REVOKE does not cascade by default — if you granted SELECT to writer and alice inherits from writer, revoking SELECT from alice directly has no effect because she still inherits it from writer. You must revoke from the group role.

```sql
trigger_lab=# RESET ROLE;
RESET
trigger_lab=# -- Remove DELETE from writer (keep SELECT, INSERT, UPDATE):
trigger_lab=# REVOKE DELETE ON ALL TABLES IN SCHEMA public FROM writer;
REVOKE
trigger_lab=# -- Remove all privileges from a role:
trigger_lab=# REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM reader;
REVOKE
trigger_lab=# -- Revoke role membership:
trigger_lab=# REVOKE reader FROM carol;
REVOKE ROLE
-- -- Re-grant for next demos:
trigger_lab=# GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;
GRANT
trigger_lab=# GRANT reader TO carol;
GRANT ROLE
```

### NOINHERIT — Explicit Privilege Activation
**Explanation:** Let us see NOINHERIT in action. We will create a deploy user that has admin_role but must explicitly activate it. This prevents accidental admin operations during normal work.

```sql
trigger_lab=# RESET ROLE;
RESET
trigger_lab=# CREATE ROLE deploy LOGIN PASSWORD 'deploy_pass' NOINHERIT;
CREATE ROLE
trigger_lab=# GRANT writer TO deploy;
GRANT ROLE
trigger_lab=# GRANT admin_role TO deploy;
GRANT ROLE
trigger_lab=# SET ROLE deploy;
SET
trigger_lab=> -- NOINHERIT: no privileges inherited yet
trigger_lab=> SELECT * FROM employees LIMIT 1;
ERROR:  permission denied for table employees
trigger_lab=> SET ROLE writer;  -- explicitly activate writer
SET
trigger_lab=> SELECT * FROM employees LIMIT 1;
  id | name  | department  | salary
-----+-------+-------------+---------
   1 | Alice | Engineering | 90000.00
(1 row)
```

### Inspecting Privileges
**Explanation:** Checking who has what privileges. PostgreSQL provides several ways to inspect permissions. The backslash dp command shows table-level privileges. The backslash du command shows role attributes. The has_table_privilege function checks specific access. And information_schema.role_table_grants shows all grants in a queryable format.

```sql
trigger_lab=# RESET ROLE;
RESET
trigger_lab=# \dp employees
                              Access privileges
 Schema |   Name    | Type  |     Access privileges
--------+-----------+-------+----------------------------
 public | employees | table | postgres=arwdDxt/postgres +
        |           |       | reader=r/postgres         +
        |           |       | writer=arw/postgres
-- -- r=SELECT, a=INSERT, w=UPDATE, d=DELETE, D=TRUNCATE, x=REFERENCES, t=TRIGGER
trigger_lab=# SELECT has_table_privilege('carol', 'employees', 'SELECT');
 has_table_privilege
---------------------
 t
trigger_lab=# SELECT has_table_privilege('carol', 'employees', 'INSERT');
 has_table_privilege
---------------------
 f
```

### Beginner Trap: Future Tables Not Covered
**Explanation:** Here is a beginner trap: you grant SELECT on all tables, create a new table, and the user cannot read it. Why? Because GRANT ON ALL TABLES only applies to tables that exist right now. Future tables do not get the grant automatically. You must use ALTER DEFAULT PRIVILEGES to set grants that apply to future objects. This is one of the most common PostgreSQL permission mistakes.

```sql
trigger_lab=# GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;
GRANT
-- -- This covers employees, products, etc. that exist NOW
trigger_lab=# CREATE TABLE new_data (id INT, value TEXT);
CREATE TABLE
trigger_lab=# SET ROLE carol;
SET
trigger_lab=> SELECT * FROM new_data;
ERROR:  permission denied for table new_data
-- -- new_data was created AFTER the GRANT!
trigger_lab=> RESET ROLE;
RESET
trigger_lab=# -- Fix: set default privileges for FUTURE tables:
trigger_lab=# ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO reader;
ALTER DEFAULT PRIVILEGES
```

### Beginner Trap: Cannot Drop Role With Dependencies
**Explanation:** Another beginner trap: you try to drop a role and get an error because the role owns objects or has privileges. PostgreSQL will not let you drop a role that owns tables, has been granted permissions, or has default privileges set. You must first reassign ownership, then revoke privileges, then drop.

```sql
trigger_lab=# DROP ROLE alice;
ERROR:  role "alice" cannot be dropped because some objects depend on it
DETAIL:  privileges for table employees
-- 
-- -- Three-step cleanup process:
trigger_lab=# -- Step 1: Reassign owned objects to another role
trigger_lab=# REASSIGN OWNED BY alice TO postgres;
REASSIGN OWNED
trigger_lab=# -- Step 2: Drop all remaining privileges
trigger_lab=# DROP OWNED BY alice;
DROP OWNED
trigger_lab=# -- Step 3: Now drop the role
trigger_lab=# DROP ROLE alice;
DROP ROLE
```

### Securing the public Schema
**Explanation:** Let us talk about the public schema and the PUBLIC role. By default, every database has a public schema that every role has CREATE and USAGE access to. This means any role can create tables in the public schema — a security risk. In production, you should revoke CREATE on the public schema from the PUBLIC pseudo-role, and only grant it to specific admin roles.

```sql
trigger_lab=# -- By default, everyone can create in public schema:
trigger_lab=# REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE
trigger_lab=# -- Keep USAGE so existing queries work:
trigger_lab=# REVOKE ALL ON DATABASE trigger_lab FROM PUBLIC;
REVOKE
trigger_lab=# -- Grant CONNECT explicitly to who needs it:
trigger_lab=# GRANT CONNECT ON DATABASE trigger_lab TO reader, writer, admin_role;
GRANT
-- -- Now only admin_role can CREATE in public schema
trigger_lab=# GRANT CREATE ON SCHEMA public TO admin_role;
GRANT
```

### Production Privilege Template
**Explanation:** Here is a complete privilege setup template you can use for any new database. This covers the most common production pattern: reader, writer, and admin groups with proper schema and default privileges.

```sql
-- 1. Lock down public schema
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON DATABASE myapp FROM PUBLIC;

-- 2. Create group roles
CREATE ROLE app_reader NOLOGIN;
CREATE ROLE app_writer NOLOGIN;
CREATE ROLE app_admin NOLOGIN;

-- 3. Grant schema access
GRANT CONNECT ON DATABASE myapp TO app_reader, app_writer, app_admin;
GRANT USAGE ON SCHEMA public TO app_reader, app_writer, app_admin;
GRANT CREATE ON SCHEMA public TO app_admin;

-- 4. Grant table privileges
GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_reader;
GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO app_writer;
GRANT ALL ON ALL TABLES IN SCHEMA public TO app_admin;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_writer, app_admin;

-- 5. Future tables (CRITICAL!)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT,INSERT,UPDATE,DELETE ON TABLES TO app_writer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO app_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO app_writer;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Trap: Future Tables Not Covered
Here is a beginner trap: you grant SELECT on all tables, create a new table, and the user cannot read it. Why? Because GRANT ON ALL TABLES only applies to tables that exist right now. Future tables do not get the grant automatically. You must use ALTER DEFAULT PRIVILEGES to set grants that apply to future objects. This is one of the most common PostgreSQL permission mistakes.

```sql
GRANT SELECT ON ALL TABLES IN SCHEMA public TO reader;
GRANT
-- This covers employees, products, etc. that exist NOW
CREATE TABLE new_data (id INT, value TEXT);
CREATE TABLE
SET ROLE carol;
SET
SELECT * FROM new_data;
ERROR:  permission denied for table new_data
-- new_data was created AFTER the GRANT!
RESET ROLE;
RESET
-- Fix: set default privileges for FUTURE tables:
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO reader;
ALTER DEFAULT PRIVILEGES
```

### Beginner Trap: Cannot Drop Role With Dependencies
Another beginner trap: you try to drop a role and get an error because the role owns objects or has privileges. PostgreSQL will not let you drop a role that owns tables, has been granted permissions, or has default privileges set. You must first reassign ownership, then revoke privileges, then drop.

```sql
DROP ROLE alice;
ERROR:  role "alice" cannot be dropped because some objects depend on it
DETAIL:  privileges for table employees

-- Three-step cleanup process:
-- Step 1: Reassign owned objects to another role
REASSIGN OWNED BY alice TO postgres;
REASSIGN OWNED
-- Step 2: Drop all remaining privileges
DROP OWNED BY alice;
DROP OWNED
-- Step 3: Now drop the role
DROP ROLE alice;
DROP ROLE
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. In PostgreSQL, users and roles are the same thing — CREATE USER equals CREATE ROLE WITH LOGIN. Build privilege hierarchies using group roles with NOLOGIN and grant membership to login users. Use GRANT for existing objects and ALTER DEFAULT PRIVILEGES for future objects. INHERIT means automatic privilege activation, NOINHERIT requires SET ROLE. Always secure the public schema by revoking CREATE from PUBLIC. To drop a role: REASSIGN OWNED, DROP OWNED, then DROP ROLE.

- **CREATE USER = CREATE ROLE WITH LOGIN (identical)**
- **Group pattern: NOLOGIN roles hold permissions, users inherit**
- **GRANT SELECT/INSERT/UPDATE/DELETE ON table TO role**
- **GRANT USAGE ON SCHEMA required to see objects**
- **ALTER DEFAULT PRIVILEGES: covers FUTURE tables**
- **INHERIT: auto-gets group privileges. NOINHERIT: must SET ROLE**
- **\dp: inspect table privileges. has_table_privilege(): check specific**
- **REVOKE CREATE ON SCHEMA public FROM PUBLIC (security)**
- **Drop role: REASSIGN OWNED BY → DROP OWNED BY → DROP ROLE**
- **Trap: GRANT ON ALL TABLES does NOT cover future tables**


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
