# EDB Postgres Advanced Server (EPAS) — Oracle Compatibility Features
**Series:** PostgreSQL Mastery | **Phase:** 29 | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome to PostgreSQL Mastery. In this class, we explore EDB Postgres Advanced Server — EPAS — the commercial PostgreSQL distribution that adds Oracle compatibility features. If your organization is migrating from Oracle, EPAS can significantly reduce the conversion effort.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites
Before this class, you should understand community PostgreSQL administration, PL/pgSQL basics, and the Oracle migration concepts from Phase 28. Familiarity with Oracle PL/SQL helps you appreciate what EPAS provides.

| Term | Meaning / Explanation |
| :--- | :--- |
| **PostgreSQL Admin** | Community PG installation, configuration, PL/pgSQL — Phases 1-28 |
| **Oracle Awareness** | Basic PL/SQL syntax, packages, Oracle data types (helpful, not required) |
| **Migration Context** | Ora2Pg and migration planning from Phase 28 |

### EPAS = Community PG + Oracle Compatibility
EPAS is community PostgreSQL plus Oracle compatibility. It runs standard PostgreSQL workloads identically to community PostgreSQL — all your PL/pgSQL code, extensions, and tools work. On top of that, EPAS adds Redwood compatibility mode which enables Oracle PL/SQL syntax, packages, Oracle data types, and Oracle-compatible built-in functions. Think of it as PostgreSQL with an Oracle translation layer.

```
[Oracle
Compatibility Layer]
[EDB Enterprise Tools
(PEM, EFM, BART)]
[Community PostgreSQL 16 Core Engine]
```

### Comparison
EPAS has two modes. PostgreSQL mode works identically to community PostgreSQL. Redwood mode enables Oracle compatibility — Oracle-style empty string equals NULL behavior, Oracle date handling where DATE includes time, Oracle-compatible catalog views, and Oracle PL/SQL syntax. You choose the mode when creating the database. Most Oracle migrations use Redwood mode.

| PostgreSQL Mode | Redwood Mode (Oracle) |
| :--- | :--- |
| Identical to community PG | Oracle compatibility enabled |
| Empty string ≠ NULL | Empty string = NULL (like Oracle) |
| DATE = date only (no time) | DATE includes time (like Oracle) |
| Standard PL/pgSQL | PL/SQL syntax supported |
| Standard catalog views | Oracle-compatible catalog views |
| Use for new PG projects | Use for Oracle migrations |

### Oracle Built-in Packages in EPAS
EPAS includes implementations of many Oracle built-in packages. DBMS_OUTPUT for debug printing, UTL_FILE for file operations, DBMS_SQL for dynamic SQL, DBMS_JOB and DBMS_SCHEDULER for job scheduling, DBMS_LOB for large object handling, and DBMS_CRYPTO for encryption. Not every Oracle package is supported, but the most commonly used ones are.

| Term | Meaning / Explanation |
| :--- | :--- |
| **DBMS_OUTPUT** | EPAS Support: Full | Notes: PUT_LINE, GET_LINE, ENABLE, DISABLE |
| **UTL_FILE** | EPAS Support: Full | Notes: File read/write from PL/SQL |
| **DBMS_SQL** | EPAS Support: Full | Notes: Dynamic SQL execution |
| **DBMS_JOB** | EPAS Support: Full | Notes: Job scheduling (legacy) |
| **DBMS_SCHEDULER** | EPAS Support: Partial | Notes: Basic scheduling supported |
| **DBMS_LOB** | EPAS Support: Full | Notes: Large object operations |
| **DBMS_CRYPTO** | EPAS Support: Full | Notes: Encryption/hashing |
| **DBMS_PIPE** | EPAS Support: Full | Notes: Inter-session communication |
| **DBMS_LOCK** | EPAS Support: Full | Notes: User-defined locks |
| **UTL_MAIL** | EPAS Support: Full | Notes: Send email from PL/SQL |
| **DBMS_PROFILER** | EPAS Support: Full | Notes: PL/SQL code profiling |
| **UTL_HTTP** | EPAS Support: Partial | Notes: HTTP requests from PL/SQL |

### Oracle Data Types Supported in EPAS
EPAS supports Oracle data types natively in Redwood mode. NUMBER works as in Oracle — NUMBER without precision, NUMBER with precision and scale, and NUMBER used as PLS_INTEGER. VARCHAR2, NVARCHAR2, NCHAR, RAW, LONG, and CLOB all work. This means you do not need to convert Oracle data types during migration — they work as-is on EPAS.

| Term | Meaning / Explanation |
| :--- | :--- |
| **NUMBER** | EPAS Behavior: Native (Oracle semantics) | Mapped To: numeric |
| **NUMBER(p,s)** | EPAS Behavior: Native | Mapped To: numeric(p,s) |
| **VARCHAR2(n)** | EPAS Behavior: Native | Mapped To: varchar(n) |
| **NVARCHAR2(n)** | EPAS Behavior: Native | Mapped To: varchar(n) |
| **CHAR(n) / NCHAR(n)** | EPAS Behavior: Native | Mapped To: char(n) |
| **DATE** | EPAS Behavior: Includes time (Redwood mode) | Mapped To: timestamp |
| **CLOB** | EPAS Behavior: Native | Mapped To: text |
| **BLOB** | EPAS Behavior: Native | Mapped To: bytea |
| **RAW(n)** | EPAS Behavior: Native | Mapped To: bytea |
| **LONG** | EPAS Behavior: Native | Mapped To: text |
| **BINARY_FLOAT** | EPAS Behavior: Supported | Mapped To: real |
| **BINARY_DOUBLE** | EPAS Behavior: Supported | Mapped To: double precision |

### Comparison
If this deep dive into EPAS is helpful, please support the course. Your donation keeps this content free for everyone learning PostgreSQL. Links for PayPal and UPI are in the description.

| Support the Course | Free Materials |
| :--- | :--- |
| PayPal: Link in description | GitHub: Class materials (.sql) |
| UPI: Link in description | All commands from this video |
| Every donation helps! | Practice exercises included |

### When to Choose EPAS vs Community PG
EPAS makes sense in three scenarios. First, Oracle migration — when you have thousands of PL/SQL objects and converting everything to PL/pgSQL would take months or years. Second, enterprise compliance — when your organization requires vendor-backed support with SLAs for audit purposes. Third, Oracle-trained team — when your DBAs know Oracle and the learning curve to community PostgreSQL would be steep. If none of these apply, community PostgreSQL gives you the same core engine for free.

- Choose EPAS if... -- Migrating from Oracle with heavy PL/SQL code (packages, DBMS_* usage).
- Choose EPAS if... -- Enterprise compliance requires vendor-backed support with formal SLAs.
- Choose EPAS if... -- Your DBA team is Oracle-trained and needs familiar syntax during transition.
- Choose Community PG if... -- No Oracle migration. New project. Team knows PostgreSQL already.
- Choose Community PG if... -- Budget-sensitive. Community PG core engine is identical to EPAS core.

### Beginner Traps
Watch out for these mistakes. First, EPAS is not a different database — it is PostgreSQL with add-ons. Do not treat it as a separate product. Second, Redwood mode changes behavior globally for that database — empty string becomes NULL, DATE includes time. Test thoroughly. Third, not all Oracle features are supported — check the compatibility matrix before assuming your code will work. Fourth, EPAS license costs add up at scale — calculate per-core costs for your entire infrastructure.

- EPAS IS PostgreSQL -- Same core engine, same extensions, same tools. Oracle compat is an add-on layer, not a fork.
- Redwood mode changes behavior -- Empty string = NULL, DATE includes time. This affects ALL code in that database. Test everything.
- Not 100% Oracle compatible -- Check EDB compat matrix. Some Oracle features (Flashback, RAC, ASM) are NOT supported.
- License costs at scale -- Per-core pricing. 64-core server = significant annual cost. Calculate before committing.

### Practice Exercises
Here are your practice exercises. First, if you have access to EPAS trial, create a database in Redwood mode and test that empty string equals NULL. Second, take an Oracle package from Phase 28 and run it directly on EPAS — verify it works without conversion. Third, create a profile with password policies and assign it to a test user. Fourth, compare the same PL/SQL code running on EPAS versus the converted PL/pgSQL on community PostgreSQL.

- Exercise 1 -- Install EPAS trial. Create DB in Redwood mode. Test: SELECT '' IS NULL — should return TRUE.
- Exercise 2 -- Run the Oracle employee_pkg package from Phase 28 directly on EPAS. Verify it works unchanged.
- Exercise 3 -- Create a profile with FAILED_LOGIN_ATTEMPTS=3. Assign to user. Test lockout after 3 failures.
- Exercise 4 -- Compare: same PL/SQL on EPAS vs converted PL/pgSQL on community PG. Verify identical results.


---

## 3. Hands-On Commands & psql Output

### Oracle PL/SQL Running on EPAS
**Explanation:** The biggest Oracle compatibility feature is PL/SQL support. EPAS runs Oracle PL/SQL packages, procedures, and functions with minimal or no changes. Packages with specification and body work natively. DBMS_OUTPUT, UTL_FILE, DBMS_SQL, and other built-in Oracle packages are included. This means Oracle code migrated with Ora2Pg often runs directly on EPAS without the manual PL/pgSQL conversion step.

```sql
-- This Oracle PL/SQL runs DIRECTLY on EPAS:
CREATE OR REPLACE PACKAGE employee_pkg AS
  FUNCTION get_salary(p_emp_id NUMBER)
    RETURN NUMBER;
  PROCEDURE raise_salary(
    p_emp_id NUMBER, p_amount NUMBER);
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

  PROCEDURE raise_salary(
    p_emp_id NUMBER, p_amount NUMBER) IS
  BEGIN
    UPDATE employees
    SET salary = salary + p_amount
    WHERE emp_id = p_emp_id;
    DBMS_OUTPUT.PUT_LINE('Salary updated');
  END;
END employee_pkg;
```

### Synonyms and Database Links in EPAS
**Explanation:** EPAS supports Oracle-style public and private synonyms. A synonym is an alias for a database object — it lets you reference a table in another schema without using the schema prefix. EPAS also supports Oracle-style database links for querying remote databases. These features do not exist in community PostgreSQL.

```sql
-- Private synonym (per-user alias):
CREATE SYNONYM emp FOR hr.employees;
SELECT * FROM emp;  -- queries hr.employees

-- Public synonym (available to all users):
CREATE PUBLIC SYNONYM departments
  FOR hr.departments;

-- Database link (query remote database):
CREATE DATABASE LINK remote_oracle
  CONNECT TO remote_user
  IDENTIFIED BY 'password'
  USING 'remote-server:1521/ORCL';

-- Query through database link:
SELECT * FROM employees@remote_oracle
WHERE department_id = 10;

-- Drop synonym:
DROP SYNONYM emp;
DROP PUBLIC SYNONYM departments;
```

### EDB Profiles (Oracle-Compatible)
**Explanation:** EPAS includes Oracle-compatible profiles for password policies and resource limits. A profile defines rules like password lifetime, failed login attempts before lock, password reuse restrictions, and session resource limits like CPU time and idle timeout. Community PostgreSQL has no profile feature — you need extensions or external tools for this.

```sql
-- Create a password policy profile:
CREATE PROFILE secure_profile LIMIT
  FAILED_LOGIN_ATTEMPTS 5
  PASSWORD_LOCK_TIME 1/24    -- lock for 1 hour
  PASSWORD_LIFE_TIME 90      -- expire after 90 days
  PASSWORD_REUSE_TIME 365    -- can't reuse for 1 year
  PASSWORD_REUSE_MAX 12      -- remember 12 passwords
  PASSWORD_GRACE_TIME 7;     -- 7-day grace after expiry

-- Assign profile to a user:
ALTER USER app_user PROFILE secure_profile;

-- View profiles:
SELECT * FROM dba_profiles
WHERE profile = 'SECURE_PROFILE';

-- Drop profile:
DROP PROFILE secure_profile CASCADE;
```


---

## 5. Common Beginner Traps & How to Fix Them

### Beginner Traps
Watch out for these mistakes. First, EPAS is not a different database — it is PostgreSQL with add-ons. Do not treat it as a separate product. Second, Redwood mode changes behavior globally for that database — empty string becomes NULL, DATE includes time. Test thoroughly. Third, not all Oracle features are supported — check the compatibility matrix before assuming your code will work. Fourth, EPAS license costs add up at scale — calculate per-core costs for your entire infrastructure.

- EPAS IS PostgreSQL -- Same core engine, same extensions, same tools. Oracle compat is an add-on layer, not a fork.
- Redwood mode changes behavior -- Empty string = NULL, DATE includes time. This affects ALL code in that database. Test everything.
- Not 100% Oracle compatible -- Check EDB compat matrix. Some Oracle features (Flashback, RAC, ASM) are NOT supported.
- License costs at scale -- Per-core pricing. 64-core server = significant annual cost. Calculate before committing.


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Let us review. EPAS is community PostgreSQL plus Oracle compatibility. Redwood mode enables Oracle PL/SQL, packages, data types, synonyms, and database links. Built-in Oracle packages like DBMS_OUTPUT, UTL_FILE, and DBMS_SQL work natively. Profiles provide Oracle-style password and resource policies. Choose EPAS for Oracle migration, enterprise compliance, or Oracle-trained teams. For everything else, community PostgreSQL provides the same core engine at zero cost.

- **EPAS = Community PostgreSQL + Oracle compatibility layer**
- **Redwood mode: PL/SQL, Oracle types, empty string = NULL, DATE includes time**
- **Oracle packages work natively: DBMS_OUTPUT, UTL_FILE, DBMS_SQL**
- **Synonyms and database links supported (not in community PG)**
- **Profiles for password policies and resource limits**
- **Choose EPAS for: Oracle migration, enterprise SLAs, Oracle-trained teams**
- **Community PG core engine is identical — EPAS adds compatibility, not performance**


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
