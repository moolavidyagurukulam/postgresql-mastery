# Foreign Data Wrappers — Query External Data
**Series:** PostgreSQL Mastery | **Phase:** Phase 25: Advanced Features | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! Imagine your data lives in multiple places — a CSV file, another PostgreSQL server, a MySQL database, or even a web API. Normally, you would need application code to pull data from each source and combine it. But PostgreSQL has a feature called Foreign Data Wrappers that lets you query external data sources as if they were regular local tables. Let us learn how it works.


---

## 2. Core Technical Concepts & Mechanisms

### What is a Foreign Data Wrapper?
A Foreign Data Wrapper, or FDW, is an extension that connects PostgreSQL to an external data source. It follows the SQL/MED standard — Management of External Data. You create a foreign server definition, map local users to remote credentials, and define foreign tables that appear in your schema just like regular tables.

| Term | Meaning / Explanation |
| :--- | :--- |
| **FDW Extension** | A loadable module that knows how to talk to a specific data source |
| **Foreign Server** | Connection details for the remote data source (host, port, database) |
| **User Mapping** | Maps local PostgreSQL users to remote credentials |
| **Foreign Table** | A virtual table in your schema that reads from the remote source |

**Notes:**
- Part of the SQL/MED standard (ISO/IEC 9075-9)
- Foreign tables look like regular tables to queries
- Many FDWs available: postgres_fdw, file_fdw, mysql_fdw, etc.

### FDW Architecture
Here is the architecture. Your local PostgreSQL server has the FDW extension loaded. When you query a foreign table, the FDW translates your SQL into a request for the remote data source, fetches the data, and returns it as rows.

```
[Your Application]
[Local PostgreSQL]
[FDW Extension]
[Remote PostgreSQL]
[CSV Files]
[MySQL / Other]
```

### file_fdw Options Reference
Here are the key file_fdw options you need to know.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Here are the key file_fdw options you need to know |

### Support & Materials
If you're learning from this course, here is how you can support it. Like this video, share it with someone learning PostgreSQL, and subscribe with the bell icon. Download today's class materials from the link in the description.

| Support This Course | Download Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials |
| UPI: Link in description | All SQL scripts included |
| Every bit helps! | Link in description |

### Available Foreign Data Wrappers
Now let us look at the ecosystem of available FDWs. PostgreSQL ships with postgres_fdw and file_fdw. The community has built many more for other databases, file formats, and services.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Point 1** | Now let us look at the ecosystem of available FDWs |
| **Point 2** | PostgreSQL ships with postgres_fdw and file_fdw |
| **Point 3** | The community has built many more for other databases, file formats, and services |

### FDW Setup — Four Steps (Any FDW)
The four-step setup process is the same for any FDW. Step one: create the extension. Step two: define the foreign server with connection details. Step three: create user mappings for authentication. Step four: create foreign tables.

- 1 -- Load the FDW module into PostgreSQL
- 2 -- Define connection: host, port, dbname
- 3 -- Map local user → remote credentials
- 4 -- Define columns that map to remote data

### FDW Performance Considerations
A common beginner trap — foreign tables do NOT have indexes locally. If you join a large local table with a large foreign table, PostgreSQL may fetch the entire remote table first. Use WHERE conditions that can be pushed down to the remote server, and be mindful of data volumes.

| Pushdown (Fast) | Local Processing (Slow) |
| :--- | :--- |
| WHERE conditions pushed to remote | Complex functions (not pushable) |
| Simple aggregates pushed (PG 10+) | JOINs with local tables (fetch all rows) |
| JOINs between foreign tables pushed | No local index on foreign table |
| ORDER BY pushed to remote | Large result sets transferred over network |
| LIMIT pushed to remote | Custom operators not pushed |


---

## 3. Hands-On Commands & psql Output

### file_fdw — Step 1: Create Extension & Server
**Explanation:** Let us start with file_fdw — the simplest FDW. It reads CSV and text files as foreign tables. This is built into PostgreSQL — no extra installation needed. It is great for importing reference data, configuration files, or log files.

```sql
postgres=# -- Enable the extension:
postgres=# CREATE EXTENSION file_fdw;
postgres=# -- Create a foreign server (file_fdw needs no connection):
postgres=# CREATE SERVER csv_files
    FOREIGN DATA WRAPPER file_fdw;
```

### file_fdw — Step 2: Create Foreign Table
**Explanation:** Now create a foreign table that maps to a CSV file. Each column definition matches a column in the CSV. The OPTIONS specify the filename, format, header, and delimiter.

```sql
postgres=# -- Sample CSV file: /tmp/countries.csv
postgres=# -- code,name,population,continent
postgres=# -- US,United States,331000000,North America
postgres=# -- IN,India,1380000000,Asia
postgres=# -- BR,Brazil,212000000,South America
postgres=# -- DE,Germany,83000000,Europe
postgres=# -- Create foreign table:
postgres=# CREATE FOREIGN TABLE countries_csv (
    code text,
    name text,
    population bigint,
    continent text
)
SERVER csv_files
OPTIONS (
    filename '/tmp/countries.csv',
    format 'csv',
    header 'true'
);
postgres=# -- Query it like a regular table:
postgres=# SELECT name, population FROM countries_csv
postgres-# WHERE continent = 'Asia';
  name  | population
postgres=# --------+------------
 India  | 1380000000
```

### Joining Foreign Tables with Local Tables
**Explanation:** You can join foreign tables with local tables, use them in subqueries, and aggregate them. The only limitation is that file_fdw tables are read-only — you cannot INSERT, UPDATE, or DELETE.

```sql
postgres=# -- Local table:
postgres=# CREATE TABLE offices (
    id serial PRIMARY KEY,
    city text NOT NULL,
    country_code text NOT NULL
);
postgres=# INSERT INTO offices (city, country_code) VALUES
('New York', 'US'), ('Mumbai', 'IN'), ('Berlin', 'DE');
postgres=# -- Join local table with foreign CSV table:
postgres=# SELECT o.city, c.name AS country, c.continent
postgres-# FROM offices o
postgres-# JOIN countries_csv c ON c.code = o.country_code;
   city    |    country     |    continent
postgres=# -----------+----------------+-----------------
 New York  | United States  | North America
 Mumbai    | India          | Asia
 Berlin    | Germany        | Europe
postgres=# -- Aggregation works too:
postgres=# SELECT continent, sum(population) AS total
postgres-# FROM countries_csv
postgres-# GROUP BY continent ORDER BY total DESC;
```

### file_fdw with Program Option
**Explanation:** The program option is powerful — instead of reading from a file, it runs a command and reads its output. You can use this to query compressed files, command output, or even curl an API. But be careful — it runs as the PostgreSQL system user.

```sql
postgres=# -- Read from a gzipped CSV:
postgres=# CREATE FOREIGN TABLE logs_gz (
    timestamp text,
    level text,
    message text
)
SERVER csv_files
OPTIONS (
    program 'gunzip -c /var/log/app/app.csv.gz',
    format 'csv',
    header 'true'
);
postgres=# -- Read from command output:
postgres=# CREATE FOREIGN TABLE disk_usage (
    filesystem text,
    size text,
    used text,
    avail text,
    use_pct text,
    mount text
)
SERVER csv_files
OPTIONS (
    program 'df -h | tail -n +2',
    format 'text',
    delimiter ' '
);
postgres=# -- NOTE: program option requires superuser
```

### IMPORT FOREIGN SCHEMA — Auto-Create Tables
**Explanation:** There is a shortcut for step four. Instead of defining foreign tables one by one, you can use IMPORT FOREIGN SCHEMA to automatically create foreign tables for all tables in a remote schema. This saves a huge amount of typing for databases with many tables.

```sql
postgres=# -- Instead of creating each foreign table manually:
postgres=# -- CREATE FOREIGN TABLE remote_users (...) SERVER remote;
postgres=# -- CREATE FOREIGN TABLE remote_orders (...) SERVER remote;
postgres=# -- CREATE FOREIGN TABLE remote_products (...) SERVER remote;
postgres=# -- Import ALL tables from remote public schema:
IMPORT FOREIGN SCHEMA public
postgres-# FROM SERVER remote_pg INTO local_schema;
postgres=# -- Import only specific tables:
IMPORT FOREIGN SCHEMA public
postgres-# LIMIT TO (users, orders)
postgres-# FROM SERVER remote_pg INTO local_schema;
postgres=# -- Exclude specific tables:
IMPORT FOREIGN SCHEMA public
    EXCEPT (temp_data, logs)
postgres-# FROM SERVER remote_pg INTO local_schema;
```

### Checking Pushdown with EXPLAIN VERBOSE
**Explanation:** You can check what gets pushed down to the remote server using EXPLAIN VERBOSE. Look for 'Remote SQL' in the output — that shows exactly what query PostgreSQL sends to the remote server.

```sql
postgres=# -- See what gets pushed to the remote:
postgres=# EXPLAIN VERBOSE
postgres=# SELECT name, email
postgres-# FROM remote_users
postgres-# WHERE active = true
postgres-# ORDER BY name
postgres-# LIMIT 10;
                    QUERY PLAN
postgres=# --------------------------------------------------
 Limit
   ->  Foreign Scan on remote_users
         Output: name, email
         Remote SQL: SELECT name, email
postgres-# FROM public.users
postgres-# WHERE (active = true)
postgres-# ORDER BY name ASC
postgres-# LIMIT 10::bigint
postgres=# -- ✓ WHERE, ORDER BY, and LIMIT all pushed down!
```

### Managing FDW Objects
**Explanation:** For managing foreign objects, here are the key commands you need.

```sql
postgres=# -- List all foreign servers:
postgres=# SELECT srvname, fdwname FROM pg_foreign_server
postgres-# JOIN pg_foreign_data_wrapper
postgres-# ON pg_foreign_server.srvfdw = pg_foreign_data_wrapper.oid;
postgres=# -- List all foreign tables:
postgres=# \dE+
postgres=# -- List all user mappings:
postgres=# SELECT * FROM pg_user_mappings;
postgres=# -- Drop in reverse order:
postgres=# DROP FOREIGN TABLE IF EXISTS countries_csv;
postgres=# DROP USER MAPPING IF EXISTS
    FOR current_user SERVER csv_files;
postgres=# DROP SERVER IF EXISTS csv_files;
postgres=# DROP EXTENSION IF EXISTS file_fdw;
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your summary. Foreign Data Wrappers let you query external data as regular tables. The setup is four steps: extension, server, user mapping, foreign table. file_fdw reads CSV and text files — it is built-in and read-only. postgres_fdw connects to other PostgreSQL servers and supports read and write. Use IMPORT FOREIGN SCHEMA to auto-create tables. Check pushdown with EXPLAIN VERBOSE. In the next class, we focus entirely on postgres_fdw — the most powerful FDW for connecting PostgreSQL to PostgreSQL.

- **FDW: query external data as local tables**
- **4-step setup: extension → server → user mapping → table**
- **file_fdw: CSV/text files (built-in, read-only)**
- **postgres_fdw: remote PostgreSQL (read + write)**
- **Many community FDWs: MySQL, Oracle, MongoDB, Redis**
- **IMPORT FOREIGN SCHEMA: auto-create foreign tables**
- **Foreign tables have NO local indexes**
- **WHERE/ORDER BY/LIMIT pushed to remote (check EXPLAIN)**
- **JOINs with local tables may fetch entire remote table**
- **program option: read from command output (superuser)**
- **Next: postgres_fdw — Connect PostgreSQL to PostgreSQL**


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
