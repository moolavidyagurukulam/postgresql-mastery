# Creating & Managing Databases
**Series:** PostgreSQL Mastery | **Phase:** Phase 2: Database Objects | **Classes:** Class 09
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We have completed the foundation phase. Now we start Phase 2 ... Database Objects. These are the building blocks of everything you create in PostgreSQL. ... Today's topic is creating and managing databases. A database is where all your data lives. By the end of this class, you will know how to create, configure, modify, and drop databases like a pro. ... Let us begin!

### The Problem: Where Does Your Data Live?
Here is the situation. You are building a new application. You need a place to store its data. Do you just start creating tables? No! First, you need a database. ... But how do you create one? What options do you set? What encoding? What template? Can you change settings after creation? What happens when you need to delete a database? ... These are the questions we answer today.

- You need a place to store your application's data
- How do you create a new database?
- What options should you set? (encoding, owner, template)
- Can you change settings after creation?
- How do you safely delete a database?
- Today: Master CREATE, ALTER, and DROP DATABASE

### Why Separate Databases?
Why do we need separate databases? ... In PostgreSQL, a cluster can hold multiple databases. Each database is completely isolated. Tables in one database cannot directly access tables in another database. ... This isolation is useful. Your web application gets its own database. Your analytics system gets another. Your test environment gets a third. ... Each database has its own schemas, tables, users, and permissions. If you drop one database, the others are completely unaffected.


---

## 2. Core Technical Concepts & Mechanisms

### The Problem: Where Does Your Data Live?
Here is the situation. You are building a new application. You need a place to store its data. Do you just start creating tables? No! First, you need a database. ... But how do you create one? What options do you set? What encoding? What template? Can you change settings after creation? What happens when you need to delete a database? ... These are the questions we answer today.

- You need a place to store your application's data
- How do you create a new database?
- What options should you set? (encoding, owner, template)
- Can you change settings after creation?
- How do you safely delete a database?
- Today: Master CREATE, ALTER, and DROP DATABASE

### Why Separate Databases?
Why do we need separate databases? ... In PostgreSQL, a cluster can hold multiple databases. Each database is completely isolated. Tables in one database cannot directly access tables in another database. ... This isolation is useful. Your web application gets its own database. Your analytics system gets another. Your test environment gets a third. ... Each database has its own schemas, tables, users, and permissions. If you drop one database, the others are completely unaffected.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Isolation** | Tables in one DB cannot access tables in another DB |
| **Organization** | Separate apps get separate databases |
| **Security** | Each DB has its own permissions and access control |
| **Safety** | Dropping one database does not affect others |
| **Backup** | You can backup/restore individual databases |

**Notes:**
- One PostgreSQL cluster → many isolated databases

### Default Databases — Created on Install
When you install PostgreSQL, three databases are created automatically. ... postgres is the default admin database. When you connect without specifying a database, you land here. ... template1 is the template used when creating new databases. Any objects you add to template1 will automatically appear in every new database you create. ... template0 is the clean, unmodified template. It is read-only. Use it when you need a truly clean database, especially when restoring from a backup with a different encoding.

| Term | Meaning / Explanation |
| :--- | :--- |
| **When you install PostgreSQL** | three databases are created automatically |
| **Point 2** | postgres is the default admin database |
| **Point 3** | When you connect without specifying a database, you land here |
| **Point 4** | template1 is the template used when creating new databases |
| **Point 5** | Any objects you add to template1 will automatically appear in every new database you create |
| **template0 is the clean** | unmodified template |
| **Point 7** | Use it when you need a truly clean database, especially when restoring from a backup with a different encoding |

### CREATE DATABASE Options Reference
Here is a quick reference for all CREATE DATABASE options.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here is a quick reference for all CREATE DATABASE options |

### template1 vs template0
Let us talk more about templates. ... When you run CREATE DATABASE, PostgreSQL copies template1 to make the new database. If you add tables, functions, or extensions to template1, every new database will have them. ... This is useful. If every database needs the uuid-ossp extension, add it to template1 once. All future databases get it automatically. ... But be careful. Changes to template1 affect ALL future databases, not existing ones. ... template0 is the fallback clean template. Use it when you need a database with a different encoding than the cluster default, or when restoring a dump that needs a clean slate.

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
**Explanation:** Creating a database is simple. ... CREATE DATABASE followed by the name. That is it. ... Let me show you. CREATE DATABASE myapp semicolon. Done. PostgreSQL creates the database using template1 as the base, with UTF8 encoding, owned by the current user. ... You can verify with backslash l to list all databases. There it is ... myapp. ... To connect to it, use backslash c myapp. The prompt changes to show the new database name.

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
**Explanation:** CREATE DATABASE has several useful options. ... OWNER sets who owns the database. By default, the user who runs the command is the owner. ... ENCODING sets the character encoding. UTF8 is the standard and you should almost always use it. ... TEMPLATE lets you choose a different template. Use template0 for a clean start. ... LC_COLLATE and LC_CTYPE set the locale for sorting and character classification. ... CONNECTION LIMIT sets the maximum number of simultaneous connections. Minus 1 means unlimited. ... Let me show you a full example.

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
**Explanation:** After creating a database, you can modify it with ALTER DATABASE. ... You can rename it. ALTER DATABASE myapp RENAME TO myapp_v2. ... You can change the owner. ALTER DATABASE myapp_v2 OWNER TO webapp. ... You can set configuration parameters for that database. ALTER DATABASE myapp_v2 SET timezone TO Asia slash Kolkata. This setting applies only to connections to this database. ... You can also change the connection limit. ALTER DATABASE myapp_v2 CONNECTION LIMIT 50. ... One important thing ... you CANNOT change the encoding or locale after creation. Those are set forever when you create the database.

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

### DROP DATABASE — Delete Permanently
**Explanation:** To delete a database, use DROP DATABASE. ... DROP DATABASE myapp_v2 semicolon. Gone. All tables, all data, all schemas ... everything inside is permanently deleted. There is no undo. There is no recycle bin. ... Important ... you cannot drop the database you are currently connected to. You must connect to a different database first. ... Also, you cannot drop a database if other users are connected to it. PostgreSQL will give you an error. You must disconnect them first. ... In PostgreSQL 13 and later, you can use DROP DATABASE WITH FORCE to automatically terminate all connections and drop the database.

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
**Explanation:** Let me show you the most common errors you will encounter. ... Error 1 ... database already exists. If you try to create a database that already exists, PostgreSQL gives an error. Solution ... use CREATE DATABASE IF NOT EXISTS, or drop the old one first. ... Actually, PostgreSQL does not support IF NOT EXISTS for CREATE DATABASE. You have to check manually or handle the error in a script. ... Error 2 ... cannot drop the currently open database. You are connected to the database you are trying to drop. Solution ... switch to a different database first with backslash c postgres. ... Error 3 ... database is being accessed by other users. Someone else is connected. Solution ... terminate their connections first, then drop.

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
**Explanation:** Here are some useful queries for managing databases. ... To see database sizes, use pg_database_size. This shows how much disk space each database uses. ... To check who is connected and to which database, query pg_stat_activity. ... To see database-level settings, check pg_db_role_setting. ... These system views are very powerful. We will use them a lot in later classes on monitoring.

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
Let me show you the most common errors you will encounter. ... Error 1 ... database already exists. If you try to create a database that already exists, PostgreSQL gives an error. Solution ... use CREATE DATABASE IF NOT EXISTS, or drop the old one first. ... Actually, PostgreSQL does not support IF NOT EXISTS for CREATE DATABASE. You have to check manually or handle the error in a script. ... Error 2 ... cannot drop the currently open database. You are connected to the database you are trying to drop. Solution ... switch to a different database first with backslash c postgres. ... Error 3 ... database is being accessed by other users. Someone else is connected. Solution ... terminate their connections first, then drop.

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

Practice time! ... Exercise 1 ... Create a database called school. Verify it with backslash l. Connect to it with backslash c school. ... Exercise 2 ... Create a database called inventory with OWNER postgres, ENCODING UTF8, and CONNECTION LIMIT 50. ... Exercise 3 ... Rename the school database to school_v2. Change its connection limit to 20. ... Exercise 4 ... Check the size of all databases using the pg_database_size query. ... Exercise 5 ... Drop school_v2 and inventory. Use IF EXISTS for safety. Verify with backslash l.

1. Exercise 1: CREATE DATABASE school → \l → \c school
2. Exercise 2: CREATE DATABASE inventory with OWNER, ENCODING, CONNECTION LIMIT
3. Exercise 3: ALTER DATABASE school RENAME TO school_v2, set limit to 20
4. Exercise 4: Query pg_database_size for all databases
5. Exercise 5: DROP DATABASE IF EXISTS school_v2; DROP DATABASE IF EXISTS inventory;


---

## 7. Key Takeaways & Cheat Sheet

Let us summarize. ... CREATE DATABASE creates a new database. Always specify ENCODING UTF8. Use TEMPLATE template0 for a clean start. ... ALTER DATABASE modifies an existing database ... rename, change owner, set parameters. You CANNOT change encoding after creation. ... DROP DATABASE permanently deletes a database. No undo! Cannot drop the database you are connected to. Disconnect other users first. ... Three default databases: postgres for admin, template1 for the template, template0 for the clean fallback. ... In our next class, we learn about schemas ... namespaces inside a database!

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
