# Extensions — Install, Manage & Explore
**Series:** PostgreSQL Mastery | **Phase:** Phase 26: Extensions | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! We now enter Phase 26 — Extensions. PostgreSQL is often called the most extensible database in the world. Extensions add new data types, functions, operators, index types, and even entire features — without modifying the core database. Full-text search, JSON operators, GIN indexes — many features you already know started as extensions. Today we learn how to find, install, manage, and create extensions.


---

## 2. Core Technical Concepts & Mechanisms

### What is a PostgreSQL Extension?
What is an extension? It is a package that bundles SQL objects — functions, types, operators, tables, indexes — into a single installable unit. Instead of running hundreds of CREATE statements, you run one command: CREATE EXTENSION. The extension system tracks versions, handles upgrades, and manages dependencies.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Extension** | A packaged collection of SQL objects installed as a single unit |
| **Contrib Modules** | Extensions shipped with PostgreSQL (in the 'contrib' directory) |
| **Third-Party** | Extensions built by the community (installed separately) |
| **Extension Files** | .control file (metadata) + .sql files (objects to create) |

**Notes:**
- Extensions are installed per-database, not per-cluster
- Some extensions need shared_preload_libraries (server restart)
- Superuser or CREATE privilege required to install

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Essential Contrib Extensions
Let us look at the most important contrib extensions and what they do. We will cover several of these in detail in upcoming classes.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Let us look at the most important contrib extensions and what they do |
| **Point 2** | We will cover several of these in detail in upcoming classes |

### Popular Community Extensions
And here are the most popular community extensions — these are not shipped with PostgreSQL and must be installed separately.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | And here are the most popular community extensions — these are not shipped with PostgreSQL and must be installed separately |

### Installing Extensions on Windows
On Windows, extensions are installed differently. Some come as Windows installers, others need to be compiled. The Stack Builder that comes with the EnterpriseDB installer can install popular extensions. For manual installation, you copy the DLL and SQL files to the right directories.

- 1 -- Open Stack Builder from Start Menu → select PostgreSQL 16 → pick extensions
- 2 -- Get .dll + .control + .sql files from the extension project
- 3 -- C:\Program Files\PostgreSQL\16\lib\
- 4 -- C:\Program Files\PostgreSQL\16\share\extension\
- 5 -- Restart PostgreSQL service from Services panel
- 6 -- CREATE EXTENSION extension_name;

### Common Extension Mistakes
A common beginner trap — trying to CREATE EXTENSION before installing the package on the operating system. The extension files must exist on disk before PostgreSQL can load them. Also, extensions that need shared_preload_libraries will fail silently if you skip the restart.

| The Mistake | The Fix |
| :--- | :--- |
| CREATE EXTENSION without installing package | Install OS package first (apt/dnf) |
| Forgetting shared_preload_libraries | Check extension docs for preload requirement |
| Forgetting to restart after preload change | systemctl restart postgresql-16 |
| DROP EXTENSION CASCADE without checking deps | Check pg_depend before DROP CASCADE |
| Installing as wrong user (need superuser) | Use superuser or check if extension is trusted |

### Extension Decision Framework
Here is a decision framework for when to use extensions.

- 1 -- Check if PostgreSQL core already has the feature
- 2 -- Prefer contrib (shipped with PG) over third-party
- 3 -- Check GitHub stars, last update, PostgreSQL version support
- 4 -- Verify license is compatible with your use (MIT, BSD, PostgreSQL)
- 5 -- If using RDS/Cloud SQL, check if extension is supported
- 6 -- Can it be upgraded without downtime? ALTER EXTENSION UPDATE


---

## 3. Hands-On Commands & psql Output

### List Available and Installed Extensions
**Explanation:** PostgreSQL ships with dozens of contrib extensions that are already on your system — you just need to enable them. Let us see which ones are available and which are already installed.

```sql
postgres=# -- List ALL available extensions on the system:
postgres=# SELECT name, default_version, comment
postgres-# FROM pg_available_extensions
postgres-# ORDER BY name;
        name        | default_version |       comment
postgres=# --------------------+-----------------+---------------------
 adminpack          | 2.1             | admin functions...
 amcheck            | 1.3             | verify B-tree...
 bloom              | 1.0             | bloom filter...
 btree_gin          | 1.3             | GIN for scalars...
 citext             | 1.6             | case-insensitive...
 dblink             | 1.2             | connect to other...
 file_fdw           | 1.0             | foreign-data...
 hstore             | 1.8             | key-value pairs...
 pg_stat_statements | 1.10            | track query stats
 pg_trgm            | 1.6             | trigram matching...
 pgcrypto           | 1.3             | crypto functions...
 postgres_fdw       | 1.1             | foreign-data...
 uuid-ossp          | 1.1             | UUID generation...
 ... (50+ extensions)
postgres=# -- Count available:
postgres=# SELECT count(*) FROM pg_available_extensions;
postgres=# -- ~50-60 on a typical PG 16 install
```

### Installing Extensions
**Explanation:** To install an extension, use CREATE EXTENSION. To see what is already installed in your current database, query pg_extension. Let us install a few commonly used extensions.

```sql
postgres=# -- Install an extension:
postgres=# CREATE EXTENSION pg_trgm;
postgres=# CREATE EXTENSION
postgres=# -- Install with IF NOT EXISTS (safe to repeat):
postgres=# CREATE EXTENSION IF NOT EXISTS pgcrypto;
postgres=# CREATE EXTENSION
postgres=# -- Install into a specific schema:
postgres=# CREATE EXTENSION hstore SCHEMA public;
postgres=# CREATE EXTENSION
postgres=# -- List installed extensions:
postgres=# SELECT extname, extversion, n.nspname AS schema
postgres-# FROM pg_extension e
postgres-# JOIN pg_namespace n ON e.extnamespace = n.oid
postgres-# ORDER BY extname;
   extname   | extversion | schema
postgres=# -------------+------------+--------
 hstore      | 1.8        | public
 pg_trgm     | 1.6        | public
 pgcrypto    | 1.3        | public
 plpgsql     | 1.0        | pg_catalog
```

### psql Shortcuts for Extensions
**Explanation:** The backslash-dx command in psql is the quick way to see installed extensions. And backslash-dx plus shows detailed information including which objects the extension owns.

```sql
postgres=# -- Quick list of installed extensions:
postgres=# \dx
                   List of installed extensions
   Name   | Version |   Schema   |       Description
postgres=# ----------+---------+------------+------------------------
 hstore   | 1.8     | public     | data type for key-value
 pg_trgm  | 1.6     | public     | text similarity + index
 pgcrypto | 1.3     | public     | cryptographic functions
 plpgsql  | 1.0     | pg_catalog | PL/pgSQL procedural...
postgres=# -- Detailed info (shows owned objects):
postgres=# \dx+ pgcrypto
     Objects in extension "pgcrypto"
          Object description
postgres=# -----------------------------------
 function armor(bytea)
 function armor(bytea,text[],text[])
 function crypt(text,text)
 function dearmor(text)
 function decrypt(bytea,bytea,text)
 function digest(bytea,text)
 function encrypt(bytea,bytea,text)
 function gen_random_bytes(integer)
 function gen_random_uuid()
 function gen_salt(text)
 function gen_salt(text,integer)
 function hmac(bytea,bytea,text)
 function pgp_sym_decrypt(bytea,text)
 function pgp_sym_encrypt(text,text)
 ...
```

### Managing Extensions — Upgrade, Drop, Alter
**Explanation:** Extensions can be upgraded to newer versions, dropped, or relocated to a different schema. Let us see how to manage the extension lifecycle.

```sql
postgres=# -- Check available upgrade versions:
postgres=# SELECT name, installed_version, default_version
postgres-# FROM pg_available_extensions
postgres-# WHERE installed_version IS NOT NULL
postgres-# AND installed_version <> default_version;
postgres=# -- Upgrade to latest:
postgres=# ALTER EXTENSION pg_trgm UPDATE;
postgres=# -- Upgrade to specific version:
postgres=# ALTER EXTENSION pg_trgm UPDATE TO '1.6';
postgres=# -- Move to a different schema:
postgres=# ALTER EXTENSION hstore SET SCHEMA extensions;
postgres=# -- Drop an extension:
postgres=# DROP EXTENSION hstore;
postgres=# -- Drop with dependencies (also drops objects using it):
postgres=# DROP EXTENSION hstore CASCADE;
postgres=# -- WARNING: CASCADE drops columns/tables using hstore type!
postgres=# -- Safe: check dependencies first:
postgres=# SELECT * FROM pg_depend
postgres-# WHERE refobjid = (SELECT oid FROM pg_extension
postgres-# WHERE extname = 'hstore');
```

### shared_preload_libraries — Extensions That Need Restart
**Explanation:** Some extensions need to be loaded when PostgreSQL starts — they add background workers or hook into the query processing pipeline. These go in the shared_preload_libraries parameter in postgresql.conf. A restart is required after changing this setting.

```sql
postgres=# -- Check current preloaded libraries:
postgres=# SHOW shared_preload_libraries;
postgres=# -- (empty by default)
postgres=# -- Extensions that need preloading:
postgres=# -- pg_stat_statements  → query statistics
postgres=# -- pg_cron             → scheduled jobs
postgres=# -- auto_explain        → automatic EXPLAIN logging
postgres=# -- pg_prewarm          → cache warming
postgres=# -- pgaudit             → audit logging
postgres=# -- In postgresql.conf:
postgres=# -- shared_preload_libraries = 'pg_stat_statements,pg_cron'
postgres=# -- After editing, restart PostgreSQL:
postgres=# -- sudo systemctl restart postgresql-16
postgres=# -- Then create the extension:
postgres=# CREATE EXTENSION pg_stat_statements;
postgres=# -- This only works AFTER the library is preloaded
```

### Installing Third-Party Extensions (Linux)
**Explanation:** Installing a third-party extension on Linux involves three steps: install the OS package, optionally add it to shared_preload_libraries if required, then CREATE EXTENSION in your database.

```sql
# Debian/Ubuntu — install from PGDG repo:
sudo apt install postgresql-16-pg-cron
sudo apt install postgresql-16-pgaudit
sudo apt install postgresql-16-postgis-3
# RHEL/CentOS/Rocky:
sudo dnf install pg_cron_16
sudo dnf install pgaudit_16
sudo dnf install postgis34_16
# If extension needs preloading, edit postgresql.conf:
sudo nano /etc/postgresql/16/main/postgresql.conf
# shared_preload_libraries = 'pg_cron'
# Restart PostgreSQL:
sudo systemctl restart postgresql-16
# Then in psql:
postgres=# CREATE EXTENSION pg_cron;
```

### Extension File Structure
**Explanation:** Let us look at the internal structure of an extension. Every extension has a control file that describes it, and one or more SQL files that contain the objects to create.

```sql
# Control file: /usr/share/postgresql/16/extension/pg_trgm.control
# Contents:
# comment = 'text similarity measurement and index searching'
# default_version = '1.6'
# module_pathname = '$libdir/pg_trgm'
# relocatable = true
# trusted = true
# SQL file: /usr/share/postgresql/16/extension/pg_trgm--1.6.sql
# Contains all CREATE FUNCTION, CREATE OPERATOR, etc.
# Upgrade file: pg_trgm--1.5--1.6.sql
# Contains only changes from 1.5 to 1.6
# Key fields in .control:
#   default_version  = version to install
#   relocatable      = can move to another schema?
#   trusted          = non-superuser can install?
#   requires         = depends on other extensions
#   module_pathname  = path to shared library (.so/.dll)
```

### Trusted Extensions (Non-Superuser Install)
**Explanation:** PostgreSQL 13 introduced trusted extensions — extensions that non-superusers can install if they have CREATE privilege on the database. This is a security improvement. Let us check which extensions are trusted.

```sql
postgres=# -- List trusted extensions:
postgres=# SELECT name, trusted, comment
postgres-# FROM pg_available_extensions
postgres-# WHERE trusted = true
postgres-# ORDER BY name;
     name     | trusted |        comment
postgres=# --------------+---------+------------------------
 btree_gin    | t       | GIN operator classes...
 btree_gist   | t       | GiST operator classes..
 citext       | t       | case-insensitive char..
 hstore       | t       | key-value data type
 ltree        | t       | hierarchical labels
 pg_trgm      | t       | text similarity...
 pgcrypto     | t       | cryptographic functions
 tablefunc    | t       | crosstab and pivot...
 uuid-ossp    | t       | generate UUIDs
postgres=# -- Non-superuser with CREATE privilege can install:
postgres=# -- GRANT CREATE ON DATABASE mydb TO app_user;
postgres=# -- Then as app_user:
postgres=# -- CREATE EXTENSION citext;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Common Extension Mistakes
A common beginner trap — trying to CREATE EXTENSION before installing the package on the operating system. The extension files must exist on disk before PostgreSQL can load them. Also, extensions that need shared_preload_libraries will fail silently if you skip the restart.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Extensions add features to PostgreSQL without modifying the core. Use CREATE EXTENSION to install, ALTER EXTENSION to upgrade, DROP EXTENSION to remove. Contrib extensions ship with PostgreSQL — just CREATE EXTENSION. Third-party extensions need OS package installation first. Some extensions need shared_preload_libraries and a restart. Trusted extensions can be installed by non-superusers. Check pg_available_extensions for what is on your system. In the next class, we learn pg_cron — running scheduled jobs directly inside PostgreSQL.

- **Extension: packaged SQL objects (functions, types, operators)**
- **CREATE EXTENSION name: install into current database**
- **ALTER EXTENSION name UPDATE: upgrade to latest version**
- **DROP EXTENSION name [CASCADE]: remove (CASCADE = remove deps too)**
- **\dx: list installed extensions in psql**
- **pg_available_extensions: all extensions on the system**
- **Contrib: shipped with PostgreSQL (~50 extensions)**
- **Third-party: install OS package first, then CREATE EXTENSION**
- **shared_preload_libraries: for extensions needing server hooks**
- **Trusted extensions: non-superuser can install (PG 13+)**
- **Next: pg_cron — Scheduled Jobs**


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
