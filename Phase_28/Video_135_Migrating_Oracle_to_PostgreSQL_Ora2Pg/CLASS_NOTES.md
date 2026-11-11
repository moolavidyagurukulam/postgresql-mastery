# Migrating Oracle to PostgreSQL — Ora2Pg
**Series:** PostgreSQL Mastery | **Phase:** 28 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we learn how to migrate an Oracle database to PostgreSQL using Ora2Pg — the most popular open-source Oracle-to-PostgreSQL migration tool.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before starting, you should understand basic PostgreSQL administration, SQL differences between Oracle and PostgreSQL, and have access to both an Oracle source database and a PostgreSQL 16 target.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL Admin** | CREATE DATABASE, users, permissions, psql basics |
| **SQL Differences** | Oracle vs PostgreSQL syntax awareness |
| **Oracle Access** | Read access to Oracle source with DBA or SELECT privileges |
| **PostgreSQL 16 Target** | Fresh PG 16 instance ready to receive migrated data |

### Comparison
Your company runs Oracle. Licensing costs are six or seven figures per year. Oracle uses proprietary syntax — packages, sequences with CURRVAL and NEXTVAL as pseudo-columns, NVL instead of COALESCE, SYSDATE instead of CURRENT_TIMESTAMP. Moving to PostgreSQL saves money and removes vendor lock-in, but manually converting thousands of objects is error-prone and slow.

| Oracle Pain Points | PostgreSQL Advantages |
| :--- | :--- |
| License: $47,500/core/year | License: $0 (open source) |
| Proprietary PL/SQL syntax | Standard SQL + PL/pgSQL |
| NVL, DECODE, SYSDATE, ROWNUM | COALESCE, CASE, NOW(), LIMIT |
| Packages (no PG equivalent) | Schemas + functions instead |
| Sequences as pseudo-columns | GENERATED ALWAYS AS IDENTITY |
| NUMBER(p,s) type system | NUMERIC, INTEGER, BIGINT |

### What Is Ora2Pg?
Ora2Pg is a free, open-source Perl tool that connects to Oracle, reads the schema and data, and converts everything to PostgreSQL-compatible SQL. It handles tables, views, sequences, indexes, constraints, triggers, functions, packages, and even data types. It does not do a perfect one-to-one conversion — some manual fixes are always needed — but it automates 80 to 95 percent of the work.

| Term | Meaning / Explanation |
| :--- | :--- |
| **Type** | Open-source Perl-based migration tool |
| **Direction** | Oracle/MySQL → PostgreSQL (one-way) |
| **Converts** | Tables, views, sequences, indexes, constraints, triggers, functions, packages, data |
| **Automation** | 80-95% automatic, 5-20% manual fix needed |
| **License** | GPLv3 — completely free |

### Ora2Pg Architecture
Here is how Ora2Pg works. It connects to Oracle using the Oracle Instant Client and Perl DBI with DBD::Oracle. It reads the Oracle data dictionary — tables, columns, types, constraints, code. Then it generates PostgreSQL-compatible DDL and data files. You load those files into PostgreSQL using psql or pg_restore.

```
[Oracle DB]
[Oracle
Instant Client]
[Ora2Pg
(Perl + DBI)]
[SQL Files
(DDL + Data)]
[PostgreSQL 16]
```

### Oracle → PostgreSQL Data Type Mapping
Understanding the data type conversion is critical. Ora2Pg maps Oracle types to PostgreSQL types automatically, but you should verify the mappings. NUMBER with no precision becomes bigint by default. VARCHAR2 becomes varchar. DATE in Oracle includes time — so it maps to timestamp, not date. CLOB becomes text. RAW becomes bytea. Here is the complete mapping table.

| Term | Meaning / Explanation |
| :--- | :--- |
| **NUMBER(p,0) p<=4** | PostgreSQL Type: smallint | Notes: Exact for small integers |
| **NUMBER(p,0) p<=9** | PostgreSQL Type: integer | Notes: Exact for standard integers |
| **NUMBER(p,0) p<=18** | PostgreSQL Type: bigint | Notes: For large integers |
| **NUMBER(p,s)** | PostgreSQL Type: numeric(p,s) | Notes: Exact decimal preserved |
| **NUMBER (no prec)** | PostgreSQL Type: bigint | Notes: Configurable via DEFAULT_NUMERIC |
| **VARCHAR2(n)** | PostgreSQL Type: varchar(n) | Notes: Direct mapping |
| **CHAR(n)** | PostgreSQL Type: char(n) | Notes: Direct mapping |
| **DATE** | PostgreSQL Type: timestamp | Notes: Oracle DATE includes time! |
| **TIMESTAMP** | PostgreSQL Type: timestamp | Notes: Direct mapping |
| **CLOB** | PostgreSQL Type: text | Notes: Unlimited text in PG |
| **BLOB / RAW** | PostgreSQL Type: bytea | Notes: Binary data |
| **LONG** | PostgreSQL Type: text | Notes: Deprecated Oracle type |

### Comparison
If this course is helping you master PostgreSQL migration, please support us. Your donation keeps this course free for everyone. Links for PayPal and UPI are in the description. Class materials with every command from this video are available on GitHub.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All commands from this video |
| Every donation helps! | Practice exercises included |

### PL/SQL → PL/pgSQL Conversion
The hardest part of Oracle migration is converting PL/SQL code to PL/pgSQL. Ora2Pg handles most common conversions automatically, but packages need manual work because PostgreSQL has no package concept. Each package becomes a schema with functions. Here are the key syntax differences Ora2Pg converts.

| Term | Meaning / Explanation |
| :--- | :--- |
| **NVL(a, b)** | PostgreSQL PL/pgSQL: COALESCE(a, b) | Auto-converted?: Yes |
| **SYSDATE** | PostgreSQL PL/pgSQL: CURRENT_TIMESTAMP | Auto-converted?: Yes |
| **DECODE(a,b,c,d)** | PostgreSQL PL/pgSQL: CASE WHEN a=b THEN c ELSE d END | Auto-converted?: Yes |
| **ROWNUM <= 10** | PostgreSQL PL/pgSQL: LIMIT 10 | Auto-converted?: Yes |
| **VARCHAR2** | PostgreSQL PL/pgSQL: VARCHAR | Auto-converted?: Yes |
| **|| (concat)** | PostgreSQL PL/pgSQL: || (same) | Auto-converted?: No change needed |
| **PACKAGE pkg_name** | PostgreSQL PL/pgSQL: CREATE SCHEMA pkg_name | Auto-converted?: Partial — needs review |
| **EXCEPTION WHEN** | PostgreSQL PL/pgSQL: EXCEPTION WHEN | Auto-converted?: Yes (minor syntax) |
| **CURSOR (explicit)** | PostgreSQL PL/pgSQL: CURSOR or FOR loop | Auto-converted?: Yes |
| **BULK COLLECT** | PostgreSQL PL/pgSQL: Array operations | Auto-converted?: No — manual rewrite |
| **DBMS_OUTPUT.PUT_LINE** | PostgreSQL PL/pgSQL: RAISE NOTICE | Auto-converted?: Yes |
| **EXECUTE IMMEDIATE** | PostgreSQL PL/pgSQL: EXECUTE | Auto-converted?: Yes |

### Oracle Features → PostgreSQL Alternatives
Some Oracle features have no direct PostgreSQL equivalent. Oracle synonyms become PostgreSQL search_path settings or views. Oracle database links become postgres_fdw foreign servers. Oracle materialized view logs use pg_logical or triggers in PostgreSQL. Know these gaps before you start — they need manual solutions.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PUBLIC SYNONYM** | PostgreSQL Alternative: search_path or VIEW | Complexity: Low |
| **DATABASE LINK** | PostgreSQL Alternative: postgres_fdw foreign server | Complexity: Medium |
| **MVIEW LOG** | PostgreSQL Alternative: Logical replication or trigger | Complexity: Medium |
| **CONNECT BY (hierarchical)** | PostgreSQL Alternative: WITH RECURSIVE CTE | Complexity: Medium |
| **FLASHBACK QUERY** | PostgreSQL Alternative: No equivalent (use backups) | Complexity: High |
| **AUTONOMOUS TRANSACTION** | PostgreSQL Alternative: dblink to self | Complexity: High |
| **GLOBAL TEMP TABLE** | PostgreSQL Alternative: ON COMMIT DROP/DELETE | Complexity: Low |
| **BITMAP INDEX** | PostgreSQL Alternative: GIN index | Complexity: Low |
| **VIRTUAL COLUMN** | PostgreSQL Alternative: GENERATED ALWAYS AS (PG 16) | Complexity: Low |

### Beginner Traps — Oracle to PostgreSQL
Watch out for these common mistakes. First, Oracle DATE includes time — if you map it to PostgreSQL date, you lose time information. Always map to timestamp. Second, Oracle treats empty string as NULL — PostgreSQL does not. Your application code may break. Third, Oracle sequence CURRVAL and NEXTVAL syntax is different — test all sequence usage. Fourth, never migrate directly to production — always migrate to a test instance first.

- Oracle DATE = timestamp -- Oracle DATE includes hours, minutes, seconds. Map to TIMESTAMP in PG, not DATE, or you lose time data.
- Empty string ≠ NULL -- Oracle: '' IS NULL evaluates TRUE. PostgreSQL: '' IS NOT NULL. Check all NVL/COALESCE logic.
- Sequence syntax differs -- Oracle: seq.NEXTVAL  PostgreSQL: nextval('seq'). Test every sequence reference in app code.
- Case sensitivity -- Oracle: unquoted names uppercase. PostgreSQL: unquoted names lowercase. Double-quoted names keep case.
- Test on staging first -- NEVER run Ora2Pg directly against production PostgreSQL. Always migrate to a test instance and validate.

### Practice Exercises
Here are your practice exercises. First, install Ora2Pg and run a SHOW_REPORT against an Oracle test database — even Oracle XE works. Second, export the HR sample schema tables and sequences, load them into PostgreSQL 16, and compare row counts. Third, take an Oracle PL/SQL function with NVL and DECODE, convert it to PL/pgSQL manually, then compare your result with what Ora2Pg generates. Fourth, use init_project to create an organized migration structure.

- Exercise 1 -- Install Ora2Pg. Run SHOW_REPORT against Oracle XE or a test Oracle database. Read the migration score.
- Exercise 2 -- Export Oracle HR schema (tables + sequences + data). Load into PG 16. Compare row counts.
- Exercise 3 -- Write an Oracle function using NVL + DECODE. Convert manually to PL/pgSQL. Compare with Ora2Pg output.
- Exercise 4 -- Use ora2pg --init_project. Explore the directory structure. Run a full schema export.
- Exercise 5 -- Convert an Oracle CONNECT BY hierarchical query to PostgreSQL WITH RECURSIVE. Verify same results.


---

## 3. Hands-On Commands & psql Output

### Install Ora2Pg — Linux
**Explanation:** Let us install Ora2Pg on Linux. First, install Oracle Instant Client — download from Oracle's website and set the environment variables. Then install the Perl Oracle driver. Finally, install Ora2Pg itself from CPAN or from source. Here are the exact commands.

```sql
$# Step 1: Install Oracle Instant Client
$sudo apt install libaio1 alien
$sudo alien -i oracle-instantclient-basic-21.12.0.0.0-1.x86_64.rpm
oracle-instantclient-basic installed
$export ORACLE_HOME=/usr/lib/oracle/21/client64
$export LD_LIBRARY_PATH=$ORACLE_HOME/lib
$# Step 2: Install Perl DBI + DBD::Oracle
$sudo apt install libdbi-perl
$sudo cpan DBD::Oracle
$# Step 3: Install Ora2Pg
$wget https://github.com/darold/ora2pg/archive/refs/tags/v24.3.tar.gz
$tar xzf v24.3.tar.gz && cd ora2pg-24.3
$perl Makefile.PL && make && sudo make install
Installing /usr/local/bin/ora2pg
```

### Migration Assessment Report
**Explanation:** Before migrating, run the assessment. Ora2Pg can analyze your Oracle database and produce a migration report. It scores each object type by complexity — from A (trivial) to C (complex, needs manual work). The report also estimates total migration effort in person-days. This helps you plan and budget the project.

```sql
$ora2pg -t SHOW_REPORT -c ora2pg.conf
-------------------------------------------
Ora2Pg Migration Assessment Report
-------------------------------------------
Object Type       Count  Invalid  Cost  Rating
TABLE               42        0     1    A-1
VIEW                18        2     3    B-3
SEQUENCE            15        0     1    A-1
FUNCTION            23        0     2    A-2
PROCEDURE           31        4     5    B-5
PACKAGE              8        1    10    C-10
TRIGGER             12        0     2    A-2
-------------------------------------------
Total estimated cost: 24 person-day(s)
Migration level: B-3 (average complexity)
```

### Export Schema Objects
**Explanation:** Now let us export the schema. Run Ora2Pg with TYPE set to TABLE to get CREATE TABLE statements. Then export sequences, views, indexes, and constraints separately. Ora2Pg converts Oracle data types automatically — NUMBER becomes integer or numeric, VARCHAR2 becomes varchar, DATE becomes timestamp, CLOB becomes text.

```sql
$# Export tables (DDL only)
$ora2pg -t TABLE -o tables.sql -c ora2pg.conf
[1] Exporting table EMPLOYEES...
[2] Exporting table DEPARTMENTS...
42 tables exported.
$# Export sequences
$ora2pg -t SEQUENCE -o sequences.sql -c ora2pg.conf
15 sequences exported.
$# Export views
$ora2pg -t VIEW -o views.sql -c ora2pg.conf
18 views exported (2 invalid skipped).
$# Export indexes and constraints
$ora2pg -t INDEX -o indexes.sql -c ora2pg.conf
$ora2pg -t CONSTRAINT -o constraints.sql -c ora2pg.conf
```

### Export and Load Data
**Explanation:** For data migration, use TYPE COPY for the fastest transfer. This generates PostgreSQL COPY format which loads much faster than INSERT statements. For very large tables, Ora2Pg can split the export into multiple files and run parallel jobs. Set JOBS to the number of CPU cores for parallel data export.

```sql
$# Export data using COPY format (fast)
$ora2pg -t COPY -o data.sql -c ora2pg.conf -j 4
[1/42] Exporting EMPLOYEES (12,847 rows)...
[2/42] Exporting DEPARTMENTS (52 rows)...
[3/42] Exporting ORDERS (1,247,832 rows)...
...
Data export complete. 42 tables, 3,847,291 total rows.
$# Load into PostgreSQL (order matters!)
$psql -U postgres -d app_db -f tables.sql
$psql -U postgres -d app_db -f sequences.sql
$psql -U postgres -d app_db -f data.sql
$psql -U postgres -d app_db -f indexes.sql
$psql -U postgres -d app_db -f constraints.sql
$psql -U postgres -d app_db -f views.sql
```

### Package → Schema + Functions
**Explanation:** Here is a concrete example. In Oracle, you have a package called employee_pkg with a function get_salary. In PostgreSQL, Ora2Pg creates a schema called employee_pkg and places the function inside it. The function signature changes slightly — return type syntax is different, and you reference it as employee_pkg.get_salary.

```sql
-- ORACLE: Package with function
CREATE OR REPLACE PACKAGE employee_pkg AS
  FUNCTION get_salary(p_emp_id NUMBER)
    RETURN NUMBER;
END employee_pkg;
/
CREATE OR REPLACE PACKAGE BODY employee_pkg AS
  FUNCTION get_salary(p_emp_id NUMBER)
    RETURN NUMBER IS
    v_salary NUMBER;
  BEGIN
    SELECT salary INTO v_salary
    FROM employees WHERE emp_id = p_emp_id;
    RETURN v_salary;
  END;
END employee_pkg;

-- POSTGRESQL: Schema + Function
CREATE SCHEMA IF NOT EXISTS employee_pkg;

CREATE OR REPLACE FUNCTION employee_pkg.get_salary(
  p_emp_id integer
) RETURNS numeric AS $$
DECLARE
  v_salary numeric;
BEGIN
  SELECT salary INTO v_salary
  FROM employees WHERE emp_id = p_emp_id;
  RETURN v_salary;
END;
$$ LANGUAGE plpgsql;
```

### Organized Migration Project
**Explanation:** For real migrations, use ora2pg --init_project to create an organized directory structure. This creates separate folders for schema, data, sources, and reports. Each folder gets its own config file. This keeps large migrations manageable instead of having one giant config file.

```sql
$ora2pg --init_project my_migration
Creating project my_migration...
  my_migration/
    config/ora2pg.conf
    schema/tables/
    schema/views/
    schema/sequences/
    schema/indexes/
    schema/constraints/
    schema/triggers/
    sources/functions/
    sources/procedures/
    sources/packages/
    data/
    reports/
$cd my_migration
$# Edit config/ora2pg.conf with your connection details
$# Then run: ./export_schema.sh
```

### Post-Migration Validation
**Explanation:** After loading, validate the migration. Compare row counts between Oracle and PostgreSQL for every table. Check that constraints are in place. Run key application queries and compare results. Ora2Pg has a built-in TEST mode that runs these checks automatically.

```sql
$# Compare row counts (run on both databases)
postgres=#SELECT schemaname, relname, n_live_tup
FROM pg_stat_user_tables ORDER BY relname;
 schemaname |    relname    | n_live_tup
------------+---------------+------------
 public     | departments   |         52
 public     | employees     |     12,847
 public     | orders        |  1,247,832
postgres=#-- Check constraints loaded
postgres=#SELECT conname, contype, conrelid::regclass
FROM pg_constraint WHERE connamespace = 'public'::regnamespace;
postgres=#-- Check indexes loaded
postgres=#SELECT indexname, tablename FROM pg_indexes
WHERE schemaname = 'public' ORDER BY tablename;
$# Rebuild stats after bulk load
$vacuumdb -U postgres -d app_db --analyze-in-stages
```


---

## 4. Configuration Parameters & Sizing Rules

### File: `postgresql.conf` — ora2pg.conf — Connection Settings
After installation, Ora2Pg creates a default config file. The most important settings are the Oracle connection and the PostgreSQL target. ORACLE_DSN uses Perl DBI format with the Oracle SID or service name. Set your Oracle user and password, then the PostgreSQL target connection string.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `ORACLE_HOME` | `/usr/lib/oracle/21/client64` | `[SETTING]` | Path to Oracle Instant Client |
| `ORACLE_DSN` | `dbi:Oracle:host=oracle-server;sid=ORCL;port=1521` | `[SETTING]` | DBI connection string |
| `ORACLE_USER` | `system` | `[SETTING]` | Oracle user with SELECT on all objects |
| `ORACLE_PWD` | `oracle_password` | `[SETTING]` | Oracle password |
| `PG_DSN` | `dbi:Pg:dbname=app_db;host=pg-server;port=5432` | `[SETTING]` | Target PostgreSQL |
| `PG_USER` | `postgres` | `[SETTING]` | PostgreSQL user |
| `PG_PWD` | `pg_password` | `[SETTING]` | PostgreSQL password |
| `SCHEMA` | `HR` | `[SETTING]` | Oracle schema to export |


### File: `postgresql.conf` — ora2pg.conf — Export Settings
Next, configure what to export. The TYPE parameter controls what Ora2Pg extracts. Set it to TABLE for schema, INSERT or COPY for data, SEQUENCE for sequences, VIEW for views, FUNCTION or PROCEDURE or PACKAGE for code objects. You typically run multiple passes — one for schema, one for data, one for code.

| Parameter | Value | Context & Reload Requirement | Guidance & Default |
| :--- | :--- | :--- | :--- |
| `TYPE` | `TABLE` | `[SETTING]` | TABLE, VIEW, SEQUENCE, FUNCTION, PROCEDURE, PACKAGE, INSERT, COPY, etc. |
| `OUTPUT` | `/migration/output/tables.sql` | `[SETTING]` | Output SQL file path |
| `DATA_LIMIT` | `10000` | `[SETTING]` | Rows per INSERT batch (for large tables) |
| `DROP_FKEY` | `1` | `[SETTING]` | Drop foreign keys before data load |
| `FKEY_DEFERRABLE` | `1` | `[SETTING]` | Make restored FKs DEFERRABLE |
| `PG_NUMERIC_TYPE` | `1` | `[SETTING]` | Convert NUMBER to int/bigint where possible |
| `DEFAULT_NUMERIC` | `bigint` | `[SETTING]` | Default for NUMBER without precision |
| `NLS_LANG` | `AMERICAN_AMERICA.AL32UTF8` | `[SETTING]` | Character encoding for export |



---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps — Oracle to PostgreSQL
Watch out for these common mistakes. First, Oracle DATE includes time — if you map it to PostgreSQL date, you lose time information. Always map to timestamp. Second, Oracle treats empty string as NULL — PostgreSQL does not. Your application code may break. Third, Oracle sequence CURRVAL and NEXTVAL syntax is different — test all sequence usage. Fourth, never migrate directly to production — always migrate to a test instance first.

- Oracle DATE = timestamp -- Oracle DATE includes hours, minutes, seconds. Map to TIMESTAMP in PG, not DATE, or you lose time data.
- Empty string ≠ NULL -- Oracle: '' IS NULL evaluates TRUE. PostgreSQL: '' IS NOT NULL. Check all NVL/COALESCE logic.
- Sequence syntax differs -- Oracle: seq.NEXTVAL  PostgreSQL: nextval('seq'). Test every sequence reference in app code.
- Case sensitivity -- Oracle: unquoted names uppercase. PostgreSQL: unquoted names lowercase. Double-quoted names keep case.
- Test on staging first -- NEVER run Ora2Pg directly against production PostgreSQL. Always migrate to a test instance and validate.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review what we covered. Ora2Pg is a free Perl-based tool that automates 80 to 95 percent of Oracle to PostgreSQL migration. Install Oracle Instant Client, DBD::Oracle, then Ora2Pg. Run SHOW_REPORT first to assess complexity. Export schema and data separately, load in the correct order. Key conversions: NUMBER to integer or numeric, DATE to timestamp, PL/SQL to PL/pgSQL. Packages become schemas with functions. Always validate row counts and test application queries after migration.

- **Ora2Pg: free, open-source Oracle → PG migration tool**
- **Run SHOW_REPORT first to assess migration complexity**
- **Export schema, data, and code separately**
- **Load order: tables → sequences → data → indexes → constraints → views → functions**
- **Key type maps: NUMBER→int/numeric, DATE→timestamp, CLOB→text**
- **Packages → schemas + functions (needs manual review)**
- **Empty string ≠ NULL: test all COALESCE/NVL logic**
- **Always migrate to test instance first, then validate**


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
