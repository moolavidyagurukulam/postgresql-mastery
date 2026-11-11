# Migrating MySQL to PostgreSQL — pgLoader
**Series:** PostgreSQL Mastery | **Phase:** 28 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we learn how to migrate a MySQL database to PostgreSQL using pgLoader — a tool that reads from MySQL and writes directly into PostgreSQL in a single command.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before starting, you should understand basic PostgreSQL administration and SQL. You need a MySQL source database with read access and a PostgreSQL 16 target instance ready to receive data.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL Admin** | CREATE DATABASE, users, permissions, psql basics |
| **MySQL Access** | Read access to MySQL source database |
| **PostgreSQL 16 Target** | Fresh PG 16 instance ready for migrated data |
| **SQL Awareness** | Basic MySQL vs PostgreSQL syntax differences |

### Comparison
MySQL is popular but has limitations that push teams toward PostgreSQL. MySQL lacks advanced features like proper JSON indexing with GIN, window functions were added late, partial indexes do not exist, CTEs were not optimized until MySQL 8, and the licensing situation changed when Oracle acquired MySQL. PostgreSQL offers all these features in a truly open-source package.

| MySQL Limitations | PostgreSQL Advantages |
| :--- | :--- |
| No partial indexes | Partial & expression indexes |
| Limited CHECK constraints (before 8.0.16) | Full CHECK constraints always |
| No JSONB with GIN indexing | JSONB + GIN = fast JSON queries |
| CTEs not optimized (pre-8.0) | CTEs fully optimized |
| No table inheritance | Table inheritance + partitioning |
| Oracle-owned (licensing concerns) | Fully open source (PostgreSQL License) |

### What Is pgLoader?
pgLoader is an open-source tool that loads data into PostgreSQL from various sources including MySQL, SQLite, MS SQL, and CSV files. Unlike mysqldump plus sed scripts, pgLoader connects to both databases simultaneously, converts schema and data on the fly, and loads directly into PostgreSQL. It handles data type conversion, index recreation, foreign keys, and even default values — all in one command.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Open-source data loading tool (Common Lisp) |
| **Sources** | MySQL, SQLite, MS SQL, CSV, fixed-width, dBase |
| **Target** | PostgreSQL (direct connection, no intermediate files) |
| **Key Feature** | Single command: reads source → converts → loads into PG |
| **Handles** | Schema, data types, indexes, FKs, defaults, views |
| **License** | PostgreSQL License (permissive, free) |

### pgLoader Architecture
Here is how pgLoader works. It connects to MySQL using a MySQL client library, reads the schema information from the information_schema, converts the data types and DDL to PostgreSQL format, then streams the data directly into PostgreSQL using the COPY protocol. No intermediate files needed.

```
[MySQL DB]
[pgLoader]
[PostgreSQL 16]
```

### MySQL → PostgreSQL Data Type Mapping
pgLoader automatically maps MySQL data types to their PostgreSQL equivalents. Most conversions are straightforward — INT stays integer, VARCHAR stays varchar. The tricky ones are TINYINT(1) which becomes boolean, DATETIME which becomes timestamp without time zone, ENUM which becomes a PostgreSQL enum type, and SET which needs a text array or a junction table.

| Term | Meaning / Explanation |
| :--- | :--- |
| **TINYINT(1)** | PostgreSQL Type: boolean | Notes: Auto-detected as bool |
| **TINYINT** | PostgreSQL Type: smallint | Notes: When not (1) |
| **INT / INTEGER** | PostgreSQL Type: integer | Notes: Direct mapping |
| **BIGINT** | PostgreSQL Type: bigint | Notes: Direct mapping |
| **FLOAT** | PostgreSQL Type: real | Notes: Single precision |
| **DOUBLE** | PostgreSQL Type: double precision | Notes: Double precision |
| **DECIMAL(p,s)** | PostgreSQL Type: numeric(p,s) | Notes: Exact decimal |
| **VARCHAR(n)** | PostgreSQL Type: varchar(n) | Notes: Direct mapping |
| **TEXT / LONGTEXT** | PostgreSQL Type: text | Notes: Unlimited text |
| **DATETIME** | PostgreSQL Type: timestamp | Notes: Without time zone |
| **TIMESTAMP** | PostgreSQL Type: timestamptz | Notes: With time zone |
| **DATE** | PostgreSQL Type: date | Notes: Direct mapping |
| **BLOB / LONGBLOB** | PostgreSQL Type: bytea | Notes: Binary data |
| **ENUM('a','b')** | PostgreSQL Type: enum type | Notes: Creates PG enum |
| **JSON** | PostgreSQL Type: json | Notes: Direct (use jsonb manually) |

### MySQL-Specific Feature Handling
MySQL has features that need special handling. AUTO_INCREMENT becomes GENERATED ALWAYS AS IDENTITY or a sequence in PostgreSQL — pgLoader handles this automatically. ENUM types get converted to PostgreSQL enum types. Unsigned integers have no direct PostgreSQL equivalent — pgLoader upcasts them: unsigned INT becomes bigint, unsigned BIGINT becomes numeric. ON UPDATE CURRENT_TIMESTAMP needs a trigger in PostgreSQL.

| Term | Meaning / Explanation |
| :--- | :--- |
| **AUTO_INCREMENT** | PostgreSQL Handling: GENERATED ALWAYS AS IDENTITY / serial | Auto?: Yes |
| **UNSIGNED INT** | PostgreSQL Handling: bigint (upcasted) | Auto?: Yes |
| **UNSIGNED BIGINT** | PostgreSQL Handling: numeric(20,0) | Auto?: Yes |
| **ENUM('a','b','c')** | PostgreSQL Handling: CREATE TYPE ... AS ENUM | Auto?: Yes |
| **SET('a','b')** | PostgreSQL Handling: text[] or junction table | Auto?: No |
| **ON UPDATE CURRENT_TIMESTAMP** | PostgreSQL Handling: Trigger function needed | Auto?: No |
| **FULLTEXT INDEX** | PostgreSQL Handling: tsvector + GIN index | Auto?: No |
| **Spatial (GEOMETRY)** | PostgreSQL Handling: PostGIS geometry | Auto?: No |
| **CHARACTER SET per column** | PostgreSQL Handling: Single DB encoding (UTF-8) | Auto?: Yes |

### Comparison
If this course is helping you with database migration, please support us. Your donation keeps this course free and updated. Links for PayPal and UPI are in the description. All class materials with every command are on GitHub.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All commands from this video |
| Every donation helps! | Practice exercises included |

### Character Set Handling
MySQL allows different character sets per column — latin1 in one column, utf8mb4 in another. PostgreSQL uses one encoding for the entire database. pgLoader converts everything to UTF-8 during migration. If your MySQL data has mixed encodings or invalid byte sequences, pgLoader will report errors. Fix these in MySQL before migrating or use the DECODING TABLE option.

- MySQL: per-column charset -- Each column can have its own character set (latin1, utf8, utf8mb4, etc.)
- PostgreSQL: single encoding -- Entire database uses one encoding. Always use UTF-8 for new databases.
- pgLoader converts automatically -- Reads source encoding, converts all data to UTF-8 during transfer.
- Check for bad data first -- SELECT col FROM tbl WHERE col != CONVERT(col USING utf8mb4) — finds invalid bytes.
- Fix encoding errors -- Clean bad data in MySQL first, or use pgLoader's 'on error stop' to find problems.

### Migration Method Comparison
You might wonder — why not just use mysqldump and sed to convert the SQL? Because mysqldump produces MySQL-specific SQL that needs extensive editing. pgLoader handles all conversions automatically, streams data using the fast COPY protocol, and runs in parallel. For a million-row table, pgLoader is typically ten to twenty times faster than importing a mysqldump file.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Setup** | mysqldump + sed: Manual (many sed rules) | pgLoader: Single command or file |
| **Type conversion** | mysqldump + sed: Manual editing | pgLoader: Automatic |
| **Data transfer** | mysqldump + sed: File-based (slow) | pgLoader: Direct streaming (fast) |
| **Parallel loading** | mysqldump + sed: No | pgLoader: Yes (workers option) |
| **Index handling** | mysqldump + sed: Manual | pgLoader: Automatic |
| **ENUM conversion** | mysqldump + sed: Manual | pgLoader: Automatic |
| **Error reporting** | mysqldump + sed: Silent failures | pgLoader: Per-table error count |
| **1M rows speed** | mysqldump + sed: ~15 minutes | pgLoader: ~45 seconds |
| **Resumable** | mysqldump + sed: No | pgLoader: Partial (table-level) |

### Beginner Traps — MySQL to PostgreSQL
Watch out for these common mistakes. First, MySQL TINYINT(1) is used as boolean — pgLoader handles this, but verify your application code checks for true or false, not zero and one. Second, MySQL allows zero dates like 0000-00-00 — PostgreSQL rejects these. Fix them in MySQL before migrating. Third, MySQL GROUP BY is lenient — PostgreSQL requires every non-aggregated column in GROUP BY. Fourth, MySQL string comparison is case-insensitive by default — PostgreSQL is case-sensitive.

- TINYINT(1) = boolean -- App code checking for 0/1 must change to TRUE/FALSE. pgLoader converts the type but not your app code.
- Zero dates: 0000-00-00 -- PostgreSQL rejects invalid dates. Fix in MySQL first: UPDATE t SET d = NULL WHERE d = '0000-00-00'.
- GROUP BY strictness -- MySQL allows non-aggregated columns not in GROUP BY. PostgreSQL requires every column. Fix your queries.
- Case sensitivity -- MySQL: 'abc' = 'ABC' is TRUE. PostgreSQL: FALSE. Use ILIKE or citext extension if needed.
- Backtick quoting -- MySQL uses `backticks` for identifiers. PostgreSQL uses "double quotes". pgLoader converts these.

### Practice Exercises
Here are your practice exercises. First, install pgLoader and run a one-command migration from a MySQL test database to PostgreSQL 16 — compare row counts. Second, write a command file with CAST rules and table filtering — migrate only specific tables. Third, find MySQL zero dates in your test data, fix them, and re-migrate. Fourth, create the ON UPDATE CURRENT_TIMESTAMP trigger replacement for a migrated table.

- Exercise 1 -- Install pgLoader. Run one-command migration from MySQL to PG 16. Compare row counts on both.
- Exercise 2 -- Write a migration.load command file with CAST rules. Migrate only 3 specific tables.
- Exercise 3 -- Insert zero dates (0000-00-00) in MySQL. Attempt migration. See error. Fix and re-migrate.
- Exercise 4 -- Create the update_modified_column() trigger function. Attach to a migrated table. Test it.
- Exercise 5 -- Migrate a MySQL database with ENUM columns. Verify the PostgreSQL enum types created by pgLoader.


---

## 3. Hands-On Commands & psql Output

### Install pgLoader
**Explanation:** Installing pgLoader is straightforward. On Debian and Ubuntu, it is in the package repository. On RHEL, use EPEL or build from source. On macOS, use Homebrew. Here are the exact commands for each platform.

```sql
$# Debian/Ubuntu
$sudo apt install pgloader
pgloader is already the newest version (3.6.10).
$# RHEL/Rocky (from EPEL)
$sudo dnf install epel-release
$sudo dnf install pgloader
$# macOS
$brew install pgloader
$# Verify installation
$pgloader --version
pgloader version "3.6.10"
compiled with SBCL 2.3.2
```

### One-Command Migration
**Explanation:** The simplest migration is a single command. Pass a MySQL connection URI as the source and a PostgreSQL connection URI as the target. pgLoader reads the entire MySQL database — tables, data, indexes, constraints — and recreates everything in PostgreSQL. This works for small to medium databases.

```sql
$# Simple one-line migration
$pgloader mysql://root:password@mysql-server/app_db postgresql://postgres:pgpass@pg-server/app_db

2026-11-01T10:15:00 LOG report summary reset
                    table name   rows   errors  time
------------------------------  ------  ------  ------
          fetch meta data          42       0   0.312s
           Create Schemas           1       0   0.008s
         Create SQL Types           0       0   0.000s
          Create tables            42       0   0.187s
         Set Table OIDs            42       0   0.015s
------------------------------  ------  ------  ------
            departments            52       0   0.032s
              employees        12,847       0   1.247s
                orders      1,247,832       0  45.831s
------------------------------  ------  ------  ------
  Total streaming time:        1,260,731       0  47.127s
```

### pgLoader Command File — migration.load
**Explanation:** For production migrations, use a command file instead of the one-liner. A command file gives you fine control over schema mapping, type casting, table inclusion or exclusion, and data transformations. Save the configuration to a dot-load file and run pgLoader with that file as input.

```sql
LOAD DATABASE
  FROM mysql://root:password@mysql-server/app_db
  INTO postgresql://postgres:pgpass@pg-server/app_db

WITH
  include drop,       -- drop existing PG tables first
  create tables,      -- create tables from MySQL schema
  create indexes,     -- recreate indexes
  reset sequences,    -- set sequences to max(id) + 1
  workers = 4,        -- parallel workers
  concurrency = 2     -- concurrent table loads

SET
  maintenance_work_mem to '512MB',
  work_mem to '64MB'

CAST
  type tinyint to boolean using tinyint-to-boolean,
  type varchar to text when (= precision 65535)

INCLUDING ONLY TABLE NAMES MATCHING
  'employees', 'departments', 'orders', 'products'

BEFORE LOAD DO
  $$ CREATE SCHEMA IF NOT EXISTS app; $$

AFTER LOAD DO
  $$ VACUUM ANALYZE; $$
;
```

### Run Command File
**Explanation:** Run the command file with pgloader followed by the file path. pgLoader will execute each section in order — connect, create schema, load data, create indexes, run after-load commands. The output shows a summary table with row counts and any errors per table.

```sql
$pgloader migration.load
2026-11-01T10:30:00 LOG Starting pgloader with 4 workers
2026-11-01T10:30:00 LOG Migrating from MySQL to PostgreSQL

                    table name   rows   errors  time
------------------------------  ------  ------  ------
          Create Schemas           1       0   0.012s
          Create tables            4       0   0.098s
------------------------------  ------  ------  ------
            departments            52       0   0.028s
              employees        12,847       0   1.152s
                orders      1,247,832       0  42.417s
              products          3,891       0   0.312s
------------------------------  ------  ------  ------
        Create indexes            18       0   8.324s
       Reset Sequences             4       0   0.021s
------------------------------  ------  ------  ------
  Total streaming time:        1,264,622       0  52.364s
```

### Custom CAST Rules
**Explanation:** The CAST section in the command file lets you override default type mappings. Here are common casting rules. Convert TINYINT one to boolean. Convert VARCHAR 65535, which MySQL uses for TEXT, to PostgreSQL text. Convert DATETIME to timestamptz if your app uses time zones. You can also cast by column name for specific columns.

```sql
CAST
  -- TINYINT(1) -> boolean (default, but explicit)
  type tinyint to boolean
       using tinyint-to-boolean
       when (= precision 1),

  -- TINYINT (not 1) -> smallint
  type tinyint to smallint
       when (<> precision 1),

  -- VARCHAR(65535) is really TEXT
  type varchar to text
       when (= precision 65535),

  -- DATETIME -> timestamptz (if you want timezone)
  type datetime to timestamptz,

  -- Specific column override
  column orders.status to text
       using remove-null-characters,

  -- INT UNSIGNED -> bigint (default, but explicit)
  type int when unsigned to bigint
```

### Two-Pass Migration: Schema Then Data
**Explanation:** Sometimes you want to migrate the schema first, review it, make changes, then load data separately. Use the schema-only option in your command file. After reviewing the created tables and types, run the data-only migration. This two-pass approach gives you a chance to fix type mappings before loading millions of rows.

```sql
$# Pass 1: Schema only (no data)
$pgloader --with 'schema only' migration.load
Create tables: 42 done, 0 errors.
Create indexes: 0 (skipped in schema-only).
$# Review the created schema in psql
postgres=#\dt
         List of relations
 Schema |    Name      | Type  | Owner
--------+--------------+-------+--------
 public | departments  | table | postgres
 public | employees    | table | postgres
$# Make manual adjustments if needed
$# Pass 2: Data only
$pgloader --with 'data only' migration.load
Total streaming time: 1,260,731 rows in 47.2s
```

### Table Filtering
**Explanation:** You do not always want to migrate every table. Some tables are temporary, some are logs you want to leave behind. Use INCLUDING ONLY TABLE NAMES MATCHING to list exactly which tables to migrate. Or use EXCLUDING TABLE NAMES MATCHING to migrate everything except specific tables. Both accept regular expressions.

```sql
-- Include specific tables only:
INCLUDING ONLY TABLE NAMES MATCHING
  'employees', 'departments',
  'orders', 'products',
  ~/^audit_/               -- regex: all audit_ tables

-- OR exclude specific tables:
EXCLUDING TABLE NAMES MATCHING
  'temp_import',
  'debug_log',
  ~/^_backup_/,            -- regex: all _backup_ tables
  ~/^wp_/                  -- regex: skip WordPress tables

-- Include specific schemas (MySQL databases):
INCLUDING ONLY TABLE NAMES MATCHING
  'employees', 'departments'
  IN SCHEMA 'hr'

-- Rename schema during migration:
ALTER SCHEMA 'app_db' RENAME TO 'public'
```

### Replacing ON UPDATE CURRENT_TIMESTAMP
**Explanation:** MySQL's ON UPDATE CURRENT_TIMESTAMP automatically updates a timestamp column when the row changes. PostgreSQL has no built-in equivalent. You need a trigger function. Here is the standard pattern — create the function once, then attach it to every table that needs auto-updated timestamps.

```sql
-- MySQL had:
-- updated_at DATETIME ON UPDATE CURRENT_TIMESTAMP

-- PostgreSQL replacement:
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach to each table that needs it:
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON employees
  FOR EACH ROW
  EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_modified_column();
```

### Post-Migration Validation
**Explanation:** After migration, validate everything. Compare row counts between MySQL and PostgreSQL. Check that all indexes were created. Verify foreign key constraints are in place. Run your application's key queries against both databases and compare results. Then rebuild PostgreSQL optimizer statistics with VACUUM ANALYZE.

```sql
postgres=#-- Row counts
postgres=#SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY relname;
    relname    | n_live_tup
---------------+------------
 departments   |         52
 employees     |     12,847
 orders        |  1,247,832
 products      |      3,891
postgres=#-- Check indexes
postgres=#SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'public';
postgres=#-- Check foreign keys
postgres=#SELECT conname, conrelid::regclass, confrelid::regclass
FROM pg_constraint WHERE contype = 'f';
$vacuumdb -U postgres -d app_db --analyze-in-stages
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — MySQL to PostgreSQL
Watch out for these common mistakes. First, MySQL TINYINT(1) is used as boolean — pgLoader handles this, but verify your application code checks for true or false, not zero and one. Second, MySQL allows zero dates like 0000-00-00 — PostgreSQL rejects these. Fix them in MySQL before migrating. Third, MySQL GROUP BY is lenient — PostgreSQL requires every non-aggregated column in GROUP BY. Fourth, MySQL string comparison is case-insensitive by default — PostgreSQL is case-sensitive.

- TINYINT(1) = boolean -- App code checking for 0/1 must change to TRUE/FALSE. pgLoader converts the type but not your app code.
- Zero dates: 0000-00-00 -- PostgreSQL rejects invalid dates. Fix in MySQL first: UPDATE t SET d = NULL WHERE d = '0000-00-00'.
- GROUP BY strictness -- MySQL allows non-aggregated columns not in GROUP BY. PostgreSQL requires every column. Fix your queries.
- Case sensitivity -- MySQL: 'abc' = 'ABC' is TRUE. PostgreSQL: FALSE. Use ILIKE or citext extension if needed.
- Backtick quoting -- MySQL uses `backticks` for identifiers. PostgreSQL uses "double quotes". pgLoader converts these.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. pgLoader migrates MySQL to PostgreSQL in a single command — no intermediate files needed. It handles type conversion automatically: TINYINT(1) to boolean, DATETIME to timestamp, ENUM to PostgreSQL enum. Use a command file for production migrations with CAST rules, table filtering, and parallel workers. Fix MySQL-specific issues first: zero dates, ON UPDATE CURRENT_TIMESTAMP, GROUP BY, and case sensitivity. Always validate row counts and test application queries after migration.

- **pgLoader: single-command MySQL → PG migration**
- **Direct streaming — no intermediate SQL files**
- **Auto type conversion: TINYINT(1)→bool, DATETIME→timestamp**
- **Command file for production: CAST rules, table filters, parallel workers**
- **Fix MySQL zero dates before migrating (PG rejects 0000-00-00)**
- **Replace ON UPDATE CURRENT_TIMESTAMP with trigger function**
- **PostgreSQL GROUP BY is strict — fix queries**
- **Always validate: row counts, indexes, foreign keys, app queries**


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
