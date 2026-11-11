# Migrating SQL Server to PostgreSQL
**Series:** PostgreSQL Mastery | **Phase:** 28 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we learn how to migrate a Microsoft SQL Server database to PostgreSQL. Unlike Oracle and MySQL, there is no single dominant tool — we will cover the best available approaches and build a complete migration workflow.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before starting, you should understand basic PostgreSQL administration, T-SQL versus standard SQL differences, and have access to both a SQL Server source and a PostgreSQL 16 target. You will also need the pgLoader tool or the sqlserver2pgsql Perl script.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL Admin** | CREATE DATABASE, users, permissions, psql basics |
| **T-SQL Awareness** | Know SQL Server syntax differences from standard SQL |
| **SQL Server Access** | Read access to source database (db_datareader role) |
| **PostgreSQL 16 Target** | Fresh PG 16 instance ready for migrated data |

### Comparison
SQL Server is widely used in enterprise environments, but licensing is expensive — Standard Edition costs over six thousand dollars per two-core pack, and Enterprise is over fifteen thousand. SQL Server uses T-SQL, a proprietary dialect with features like TOP instead of LIMIT, square brackets for identifiers, and unique stored procedure syntax. Moving to PostgreSQL eliminates licensing costs and gives you a standards-compliant database.

| SQL Server Pain Points | PostgreSQL Advantages |
| :--- | :--- |
| License: $3,945/2-core (Standard) | License: $0 (open source) |
| Enterprise: $15,123/2-core | Standard SQL compliant |
| T-SQL proprietary dialect | LIMIT/OFFSET (standard) |
| TOP instead of LIMIT/OFFSET | Double-quote "identifiers" |
| Square bracket [identifiers] | Full Linux/Windows/macOS |
| Windows-centric (Linux limited) | Extensions ecosystem |

### Migration Tool Options
There is no single perfect SQL Server to PostgreSQL tool. Here are your main options. pgLoader supports SQL Server as a source — it handles schema and data migration. The sqlserver2pgsql Perl script generates schema conversion scripts. For schema-only, you can use SQL Server Management Studio to script objects and manually convert. For large datasets, use BCP to export CSV and PostgreSQL COPY to import.

| Term | Meaning / Explanation |
| :--- | :--- |
| **pgLoader** | Direct migration: reads SQL Server, writes to PG. Handles schema + data. |
| **sqlserver2pgsql** | Perl script: converts SSMS-generated DDL scripts to PG format. |
| **BCP + COPY** | Export CSV from SQL Server (bcp), import with PG COPY. Data only. |
| **SSMS Script + Manual** | Script objects in SSMS, manually convert T-SQL. Most control, most work. |
| **pgLoader + Manual** | Best approach: pgLoader for tables/data, manual for stored procedures. |

### SQL Server → PostgreSQL Migration
Here is the recommended approach. Use pgLoader to connect to SQL Server via FreeTDS or the Microsoft ODBC driver. pgLoader reads the schema and data, converts types, and loads into PostgreSQL. Then manually convert stored procedures and triggers from T-SQL to PL/pgSQL. This hybrid approach automates the bulk of work while giving you control over code conversion.

```
[SQL Server]
[FreeTDS /
MS ODBC Driver]
[pgLoader]
[PostgreSQL 16
(tables + data)]
[Manual Convert
(T-SQL → PL/pgSQL)]
```

### SQL Server → PostgreSQL Data Type Mapping
SQL Server has unique data types that need careful mapping. NVARCHAR and NCHAR use Unicode — map them to text or varchar in PostgreSQL which is always Unicode. UNIQUEIDENTIFIER maps to PostgreSQL uuid type. BIT maps to boolean. MONEY maps to numeric. DATETIME2 maps to timestamptz. The IMAGE type maps to bytea.

| Term | Meaning / Explanation |
| :--- | :--- |
| **INT** | PostgreSQL Type: integer | Notes: Direct mapping |
| **BIGINT** | PostgreSQL Type: bigint | Notes: Direct mapping |
| **SMALLINT** | PostgreSQL Type: smallint | Notes: Direct mapping |
| **BIT** | PostgreSQL Type: boolean | Notes: 0/1 → true/false |
| **MONEY / SMALLMONEY** | PostgreSQL Type: numeric | Notes: Exact decimal |
| **FLOAT** | PostgreSQL Type: double precision | Notes: IEEE 754 |
| **DECIMAL(p,s)** | PostgreSQL Type: numeric(p,s) | Notes: Direct mapping |
| **NVARCHAR(n)** | PostgreSQL Type: varchar(n) or text | Notes: Always Unicode in PG |
| **NCHAR(n)** | PostgreSQL Type: char(n) | Notes: Fixed-width Unicode |
| **VARCHAR(MAX)** | PostgreSQL Type: text | Notes: Unlimited text |
| **DATETIME** | PostgreSQL Type: timestamp | Notes: 3.33ms precision |
| **DATETIME2** | PostgreSQL Type: timestamp | Notes: 100ns precision |
| **DATETIMEOFFSET** | PostgreSQL Type: timestamptz | Notes: With time zone |
| **UNIQUEIDENTIFIER** | PostgreSQL Type: uuid | Notes: Native PG uuid type |
| **IMAGE / VARBINARY** | PostgreSQL Type: bytea | Notes: Binary data |
| **XML** | PostgreSQL Type: xml | Notes: Native PG xml type |

### T-SQL → PL/pgSQL Conversion
Converting stored procedures from T-SQL to PL/pgSQL requires understanding the key syntax differences. SQL Server uses BEGIN and END without dollar-quoting. Variables use at-sign in T-SQL but no prefix in PL/pgSQL. PRINT becomes RAISE NOTICE. GETDATE becomes CURRENT_TIMESTAMP. The TOP keyword becomes LIMIT. Here is the complete reference.

| Term | Meaning / Explanation |
| :--- | :--- |
| **@variable** | PL/pgSQL (PostgreSQL): variable (no prefix) | Notes: DECLARE in PL/pgSQL block |
| **GETDATE()** | PL/pgSQL (PostgreSQL): CURRENT_TIMESTAMP | Notes: Or NOW() |
| **TOP 10** | PL/pgSQL (PostgreSQL): LIMIT 10 | Notes: At end of query |
| **ISNULL(a, b)** | PL/pgSQL (PostgreSQL): COALESCE(a, b) | Notes: Standard SQL |
| **PRINT 'msg'** | PL/pgSQL (PostgreSQL): RAISE NOTICE 'msg' | Notes: Debug output |
| **CONVERT(type, val)** | PL/pgSQL (PostgreSQL): val::type or CAST() | Notes: PG cast syntax |
| **EXEC sp_name** | PL/pgSQL (PostgreSQL): CALL proc_name() | Notes: PG 11+ for procedures |
| **IDENTITY(1,1)** | PL/pgSQL (PostgreSQL): GENERATED ALWAYS AS IDENTITY | Notes: Standard syntax |
| **NEWID()** | PL/pgSQL (PostgreSQL): gen_random_uuid() | Notes: PG 13+ built-in |
| **RAISERROR** | PL/pgSQL (PostgreSQL): RAISE EXCEPTION | Notes: Error handling |
| **TRY...CATCH** | PL/pgSQL (PostgreSQL): BEGIN...EXCEPTION | Notes: Error blocks |
| **NOLOCK hint** | PL/pgSQL (PostgreSQL): READ UNCOMMITTED (rare) | Notes: MVCC makes it unnecessary |

### Comparison
If this migration guide is helping you, please support the course. Your donation keeps it free for everyone. Links for PayPal and UPI are in the description. Class materials with every command are available on GitHub.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All commands from this video |
| Every donation helps! | Practice exercises included |

### Schema Mapping Strategy
SQL Server uses the dbo schema by default. PostgreSQL uses public. During migration, you want to map dbo to public so your application does not need schema-qualified table names. In pgLoader, use ALTER SCHEMA dbo RENAME TO public. If your SQL Server has multiple schemas, decide which ones to keep and which to merge.

- SQL Server default: dbo -- Most objects live in dbo schema. Other schemas possible: sales, hr, etc.
- PostgreSQL default: public -- Objects without schema prefix go to public. search_path controls resolution.
- Map dbo → public -- ALTER SCHEMA 'dbo' RENAME TO 'public' in pgLoader command file.
- Keep other schemas -- SQL Server schemas like sales, hr can stay as-is in PostgreSQL.
- Update search_path -- SET search_path = public, sales, hr; — so unqualified names resolve correctly.

### SQL Server Features → PostgreSQL Alternatives
Some SQL Server features need workarounds in PostgreSQL. Linked Servers become postgres_fdw. SQL Agent jobs become pg_cron or OS cron. SSRS reports need replacement with tools like Metabase or Grafana. SSIS packages need replacement with tools like Apache Airflow or custom scripts. The Temporal Tables feature introduced in SQL Server 2016 needs a manual trigger-based solution in PostgreSQL.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Linked Server** | PostgreSQL Alternative: postgres_fdw | Complexity: Medium |
| **SQL Agent Jobs** | PostgreSQL Alternative: pg_cron extension or OS cron | Complexity: Low |
| **SSRS Reports** | PostgreSQL Alternative: Metabase / Grafana / pgAdmin | Complexity: Medium |
| **SSIS Packages** | PostgreSQL Alternative: Airflow / custom scripts | Complexity: High |
| **Temporal Tables** | PostgreSQL Alternative: Trigger-based audit (manual) | Complexity: High |
| **CROSS APPLY** | PostgreSQL Alternative: LATERAL JOIN | Complexity: Low (syntax change) |
| **MERGE statement** | PostgreSQL Alternative: INSERT ON CONFLICT (PG 15+) | Complexity: Medium |
| **Columnstore Index** | PostgreSQL Alternative: No direct equivalent | Complexity: High |
| **Service Broker** | PostgreSQL Alternative: LISTEN/NOTIFY or pg_amqp | Complexity: Medium |
| **Window Functions** | PostgreSQL Alternative: Same (fully supported) | Complexity: None |

### Beginner Traps — SQL Server to PostgreSQL
Watch out for these common mistakes. First, SQL Server is case-insensitive by default for string comparison — PostgreSQL is case-sensitive. Use ILIKE or the citext extension. Second, SQL Server IDENTITY columns need to become GENERATED ALWAYS AS IDENTITY — test that inserts work correctly. Third, the NOLOCK hint is meaningless in PostgreSQL because MVCC handles this differently. Fourth, SQL Server allows selecting columns not in GROUP BY — PostgreSQL does not.

- Case sensitivity -- SQL Server: 'abc' = 'ABC' is TRUE (default collation). PostgreSQL: FALSE. Use ILIKE or citext.
- IDENTITY columns -- SQL Server IDENTITY(1,1) → GENERATED ALWAYS AS IDENTITY. Test INSERT behavior.
- NOLOCK is meaningless -- PostgreSQL MVCC means readers never block writers. Remove all NOLOCK hints.
- Strict GROUP BY -- SQL Server allows non-aggregated columns not in GROUP BY (sometimes). PostgreSQL never does.
- String concatenation -- SQL Server: 'a' + 'b'. PostgreSQL: 'a' || 'b'. Plus sign does NOT concatenate strings in PG.

### Practice Exercises
Here are your practice exercises. First, install FreeTDS and pgLoader, connect to a SQL Server test instance and run a migration. Second, take a T-SQL stored procedure with at-sign variables, ISNULL, and GETDATE — convert it to PL/pgSQL. Third, export a large table from SQL Server using BCP, import into PostgreSQL using COPY, compare row counts. Fourth, convert a SQL Server CROSS APPLY query to PostgreSQL LATERAL JOIN.

- Exercise 1 -- Install FreeTDS + pgLoader. Run migration from SQL Server to PG 16. Compare row counts.
- Exercise 2 -- Convert a T-SQL procedure (with @vars, ISNULL, GETDATE) to PL/pgSQL. Test both produce same results.
- Exercise 3 -- Export a large table with BCP to CSV. Import into PG with COPY. Compare row counts and spot-check data.
- Exercise 4 -- Convert a CROSS APPLY query to LATERAL JOIN. Run both and verify identical results.
- Exercise 5 -- Map dbo schema to public. Verify application queries work without schema prefix in PostgreSQL.


---

## 3. Hands-On Commands & psql Output

### Install FreeTDS + pgLoader
**Explanation:** pgLoader connects to SQL Server through FreeTDS — an open-source TDS protocol library. Install FreeTDS first, configure the connection, then install pgLoader. Here are the exact commands for Debian and Ubuntu.

```sql
$# Step 1: Install FreeTDS
$sudo apt install freetds-dev freetds-bin tdsodbc
$# Step 2: Test SQL Server connection
$tsql -H sql-server-host -p 1433 -U sa -P 'YourPassword'
locale is "en_US.UTF-8"
locale charset is "UTF-8"
1>
$# Step 3: Install pgLoader
$sudo apt install pgloader
$pgloader --version
pgloader version "3.6.10"
```

### mssql_migration.load
**Explanation:** Here is a pgLoader command file for SQL Server migration. The connection URI uses the mssql protocol with FreeTDS. Set the SQL Server database and schema, configure type casting, and specify which tables to include. The WITH options control parallel loading and index creation.

```sql
LOAD DATABASE
  FROM mssql://sa:YourPassword@myserver/app_db
  INTO postgresql://postgres:pgpass@pg-server/app_db

WITH
  include drop,
  create tables,
  create indexes,
  reset sequences,
  workers = 4,
  concurrency = 2

SET
  maintenance_work_mem to '512MB'

INCLUDING ONLY TABLE NAMES MATCHING
  'Employees', 'Departments', 'Orders', 'Products'
  IN SCHEMA 'dbo'

CAST
  type nvarchar to text,
  type nchar to char,
  type datetime to timestamptz,
  type datetime2 to timestamptz,
  type uniqueidentifier to uuid,
  type bit to boolean,
  type money to numeric,
  type image to bytea

ALTER SCHEMA 'dbo' RENAME TO 'public'
;
```

### Run SQL Server Migration
**Explanation:** Run the command file with pgloader. It connects to SQL Server, reads the metadata, creates tables in PostgreSQL, streams the data, then creates indexes and constraints. The summary shows row counts and timing per table.

```sql
$pgloader mssql_migration.load
2026-11-01T14:00:00 LOG report summary reset
                    table name   rows   errors  time
------------------------------  ------  ------  ------
          fetch meta data           4       0   0.428s
           Create Schemas           1       0   0.010s
          Create tables             4       0   0.156s
------------------------------  ------  ------  ------
  dbo.Departments                  52       0   0.041s
  dbo.Employees                12,847       0   1.873s
  dbo.Orders                1,247,832       0  52.417s
  dbo.Products                  3,891       0   0.398s
------------------------------  ------  ------  ------
        Create indexes             18       0   9.124s
       Reset Sequences              4       0   0.024s
------------------------------  ------  ------  ------
  Total streaming time:      1,264,622       0  64.471s
```

### Stored Procedure Conversion
**Explanation:** Here is a concrete stored procedure conversion. The SQL Server procedure uses T-SQL syntax — at-sign variables, SET for assignment, ISNULL, and RAISERROR. The PostgreSQL version uses PL/pgSQL — DECLARE block, dollar-quoting, COALESCE, and RAISE EXCEPTION. Note how the structure changes but the logic stays the same.

```sql
-- SQL SERVER (T-SQL):
CREATE PROCEDURE dbo.GetEmployeeSalary
  @emp_id INT,
  @salary MONEY OUTPUT
AS
BEGIN
  SET @salary = (
    SELECT ISNULL(salary, 0)
    FROM Employees WHERE emp_id = @emp_id
  );
  IF @salary = 0
    RAISERROR('Employee not found', 16, 1);
END;

-- POSTGRESQL (PL/pgSQL):
CREATE OR REPLACE FUNCTION get_employee_salary(
  p_emp_id integer
) RETURNS numeric AS $$
DECLARE
  v_salary numeric;
BEGIN
  SELECT COALESCE(salary, 0) INTO v_salary
  FROM employees WHERE emp_id = p_emp_id;

  IF v_salary = 0 THEN
    RAISE EXCEPTION 'Employee not found';
  END IF;

  RETURN v_salary;
END;
$$ LANGUAGE plpgsql;
```

### BCP Export + COPY Import
**Explanation:** For very large tables where pgLoader is too slow or hits memory limits, use the BCP plus COPY approach. BCP is SQL Server's bulk copy tool — export each table to CSV. Then use PostgreSQL COPY to import. This gives you the fastest possible data transfer but requires separate schema creation.

```sql
$# Export from SQL Server using BCP
$bcp "SELECT * FROM app_db.dbo.Orders" queryout orders.csv -S sql-server -U sa -P pass -c -t '|' -r '\n'
1247832 rows copied.
Clock Time (ms.) Total: 12453
$# Create table in PostgreSQL first (from converted schema)
$psql -U postgres -d app_db -f orders_table.sql
$# Import using COPY
postgres=#\COPY orders FROM 'orders.csv' WITH (FORMAT csv, DELIMITER '|', NULL '')
COPY 1247832
$# Rebuild indexes after bulk load
$psql -U postgres -d app_db -f orders_indexes.sql
$vacuumdb -U postgres -d app_db --analyze-in-stages
```

### Post-Migration Validation
**Explanation:** After migration, run thorough validation. Compare row counts between SQL Server and PostgreSQL for every table. Verify all indexes and constraints exist. Run your application's most important queries against both databases and compare results. Check that views return identical data. Rebuild optimizer statistics.

```sql
postgres=#-- Compare row counts
postgres=#SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY relname;
    relname    | n_live_tup
---------------+------------
 departments   |         52
 employees     |     12,847
 orders        |  1,247,832
 products      |      3,891
postgres=#-- Verify indexes
postgres=#SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'public';
postgres=#-- Verify constraints
postgres=#SELECT conname, contype, conrelid::regclass FROM pg_constraint
WHERE connamespace = 'public'::regnamespace;
$vacuumdb -U postgres -d app_db --analyze-in-stages
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — /etc/freetds/freetds.conf
FreeTDS needs a configuration file to know how to connect to your SQL Server. Edit freetds.conf and add a server entry with the hostname, port, and TDS version. Use TDS version 7.4 for SQL Server 2012 and later. The server name you define here is what pgLoader uses in its connection string. Remember: parameters requiring a RESTART must have PostgreSQL restarted before changes take effect. Parameters requiring a RELOAD can be applied live with pg_reload_conf().

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `[global]` | `` | `[SETTING]` | Global settings section |
| `tds version` | `7.4` | `[SETTING]` | For SQL Server 2012+ |
| `client charset` | `UTF-8` | `[SETTING]` | Always use UTF-8 |
| `` | `` | `[SETTING]` |  |
| `[myserver]` | `` | `[SETTING]` | Server alias for pgLoader |
| `host` | `sql-server-host.example.com` | `[SETTING]` | SQL Server hostname or IP |
| `port` | `1433` | **`[RESTART]`** (Postmaster Restart) | SQL Server port (default 1433) (Default: 5432) |
| `tds version` | `7.4` | `[SETTING]` | Override for this server |
| `database` | `app_db` | `[SETTING]` | Default database to connect |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — SQL Server to PostgreSQL
Watch out for these common mistakes. First, SQL Server is case-insensitive by default for string comparison — PostgreSQL is case-sensitive. Use ILIKE or the citext extension. Second, SQL Server IDENTITY columns need to become GENERATED ALWAYS AS IDENTITY — test that inserts work correctly. Third, the NOLOCK hint is meaningless in PostgreSQL because MVCC handles this differently. Fourth, SQL Server allows selecting columns not in GROUP BY — PostgreSQL does not.

- Case sensitivity -- SQL Server: 'abc' = 'ABC' is TRUE (default collation). PostgreSQL: FALSE. Use ILIKE or citext.
- IDENTITY columns -- SQL Server IDENTITY(1,1) → GENERATED ALWAYS AS IDENTITY. Test INSERT behavior.
- NOLOCK is meaningless -- PostgreSQL MVCC means readers never block writers. Remove all NOLOCK hints.
- Strict GROUP BY -- SQL Server allows non-aggregated columns not in GROUP BY (sometimes). PostgreSQL never does.
- String concatenation -- SQL Server: 'a' + 'b'. PostgreSQL: 'a' || 'b'. Plus sign does NOT concatenate strings in PG.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. SQL Server to PostgreSQL migration uses pgLoader with FreeTDS for tables and data, plus manual conversion for stored procedures. Configure FreeTDS with TDS version 7.4 for modern SQL Server. Key type maps: BIT to boolean, MONEY to numeric, UNIQUEIDENTIFIER to uuid, NVARCHAR to text. T-SQL conversion: at-sign variables become plain variables, ISNULL becomes COALESCE, GETDATE becomes CURRENT_TIMESTAMP. Map dbo schema to public. For large datasets, use BCP export plus COPY import. Always validate thoroughly after migration.

- **pgLoader + FreeTDS: automated tables and data migration**
- **Manual conversion needed for stored procedures (T-SQL → PL/pgSQL)**
- **FreeTDS: TDS version 7.4 for SQL Server 2012+**
- **Key maps: BIT→boolean, MONEY→numeric, UNIQUEIDENTIFIER→uuid**
- **T-SQL: @vars→vars, ISNULL→COALESCE, GETDATE→CURRENT_TIMESTAMP**
- **Map dbo schema → public for application compatibility**
- **BCP + COPY for very large tables**
- **PostgreSQL is case-sensitive — use ILIKE or citext**


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
