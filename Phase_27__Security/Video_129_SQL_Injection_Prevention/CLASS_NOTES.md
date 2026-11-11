# SQL Injection Prevention
**Series:** PostgreSQL Mastery | **Phase:** Phase 27: Security | **Classes:** PostgreSQL 16
**Database Version:** PostgreSQL 16 | **Companion File:** [`materials.sql`](materials.sql)

---

## 1. Class Overview & Real-World Context

> Welcome back to PostgreSQL Mastery! In the previous classes, we secured authentication, encrypted connections, and protected data at rest. But there is one attack that bypasses all of that. SQL injection. If your application builds SQL queries by concatenating user input, an attacker can rewrite your queries to do anything — read any table, delete any data, or even execute operating system commands. SQL injection is the number one web application vulnerability and has been for over two decades. Today we learn exactly how it works and the patterns that prevent it completely. Let us begin.


---

## 2. Core Technical Concepts & Mechanisms

### Prerequisites & Recap
Before this class, you should understand basic SQL queries — SELECT, INSERT, UPDATE, DELETE. You should also know PL/pgSQL basics from the functions phase. Recap — in the previous class, we encrypted sensitive data at rest with pgcrypto and LUKS. Now we protect the application layer — because even if your data is encrypted, SQL injection can make the database do things it was never meant to do.

- Prerequisite: Basic SQL (SELECT, INSERT, UPDATE, DELETE)
- Prerequisite: PL/pgSQL basics (Phase 14)
- Recap: Data encryption with pgcrypto + LUKS
- Now: Protecting the application layer from SQL injection
- SQL injection bypasses auth, encryption, and firewalls

### Root Cause and Fix
The root cause is simple: the database cannot tell the difference between your SQL code and the attacker's SQL code. When you concatenate strings, the user input becomes part of the SQL syntax. The fix is equally simple: parameterized queries. Also called prepared statements or bound parameters. Instead of putting the value directly in the SQL string, you put a placeholder. The database receives the SQL structure and the values separately. The values can NEVER become SQL syntax — they are always treated as data, no matter what characters they contain.

| VULNERABLE (Concatenation) | SAFE (Parameterized Queries) |
| :--- | :--- |
| SQL + data mixed in one string | SQL structure and data sent separately |
| Database parses user input as SQL | Database treats values as DATA only |
| Single quotes break out of strings | Single quotes are just characters |
| Comments (--) bypass conditions | Comments are just characters |
| UNION adds unauthorized queries | UNION is just a text value |
| No amount of escaping is reliable | Impossible to inject SQL syntax |

### Support This Free Course
If you are learning from this course, here is how you can support the work. Like this video. Share it with someone learning PostgreSQL or web development — SQL injection is relevant to every developer. Subscribe and hit the bell icon. Download today's class materials from the link in the description. And if this free course is helping you, consider supporting through the donation link. Now let us continue with defense-in-depth strategies.

- Like this video — helps others find the course
- Share with someone learning PostgreSQL or web dev
- Subscribe + bell icon for new classes
- Download class materials (link in description)
- Support this free course: donation link in description

### ORM Safety — Common Traps
ORMs like SQLAlchemy, Django ORM, and Hibernate automatically parameterize queries. But they still have injection risks. The biggest trap is raw SQL methods. Every ORM provides a way to write raw SQL — and developers use it for complex queries. If you concatenate user input in raw SQL, you are back to square one. Another trap is the order_by or filter clauses that accept column names from user input. Column names cannot be parameterized — they are identifiers, not values. You must whitelist allowed column names.

| Safe (ORM Handles It) | Dangerous (Developer Must Fix) |
| :--- | :--- |
| User.objects.filter(name=input) | User.objects.raw('...' + input) |
| session.query(User).filter_by(name=input) | session.execute(text('...' + input)) |
| SELECT * WHERE name = :param | ORDER BY {user_input} (column injection) |
| ORM relationship traversal | Dynamic table/column names from input |
| Predefined scope/filter methods | LIKE patterns with unescaped % and _ |

### Finding SQL Injection — Detection Methods
How do you find SQL injection in existing code? There are three approaches. Code review — search for string concatenation with SQL keywords. Look for patterns like query equals select plus variable, or execute string plus parameter, or format with percent-s in SQL. Automated scanning — tools like SQLMap can test your application endpoints for injection. And PostgreSQL monitoring — watch pg_stat_statements for unusual query patterns, especially queries that contain UNION SELECT, multiple semicolons, or comment markers.

- 1. Code review: grep for string concatenation in SQL
-    Look for: 'SELECT' + var, EXECUTE str || param, f-strings in SQL
- 2. Automated scanning: SQLMap, Burp Suite, OWASP ZAP
-    Test all input fields, URL parameters, headers
- 3. PostgreSQL monitoring: watch pg_stat_statements
-    Look for: UNION SELECT, multiple semicolons, -- comments
- 4. Application logs: unusual error messages
-    Syntax errors from failed injection attempts

### Practice Exercises
Here are your practice exercises. One — create a vulnerable function using EXECUTE with concatenation, then inject it. Then fix it with format and USING. Two — set up a restricted application role with only SELECT and INSERT on specific tables. Try running DROP TABLE as that role. Three — write a safe dynamic search function with whitelist validation. Four — audit an existing PL/pgSQL function for injection risks. Five — test a LIKE query with percent and underscore in user input, then fix the escaping.

- 1. Create a vulnerable function, inject it, then fix it
- 2. Create a least-privilege app role — test DROP (should fail)
- 3. Write a safe dynamic search with whitelist + format(%I)
- 4. Audit an existing PL/pgSQL function for injection risks
- 5. Test LIKE with %/_ in input, fix with proper escaping


---

## 3. Hands-On Commands & psql Output

### How SQL Injection Works — Login Bypass
**Explanation:** Here is a login form. The user types their username and password. The application builds a SQL query by concatenating the input directly into the string. If the user types a normal username and password, the query works correctly. But what if the user types something malicious in the username field? They type: admin followed by single-quote, space, dash-dash. The single quote closes the string literal, and the double-dash comments out the rest of the query — including the password check. The resulting query becomes SELECT star FROM users WHERE username equals admin — and the password check is gone. The attacker logs in as admin without knowing the password.

```sql
-- Application code (Python, Java, etc.) does this:
-- query = "SELECT * FROM users WHERE username = '" + input + "' AND password = '" + pass + "'"

-- Normal input: username = 'alice', password = 'secret'
SELECT * FROM users
WHERE username = 'alice' AND password = 'secret';
-- Works correctly: returns alice's row if password matches

-- Malicious input: username = admin' --
SELECT * FROM users
WHERE username = 'admin' --' AND password = 'anything';
                         ^^^^^^^^^^^^^^^^^^^^^^^^^^^
                         This part is now a COMMENT!
-- Returns admin's row — NO password check!
```

### SQL Injection — Dangerous Payloads
**Explanation:** It gets worse. An attacker can use UNION SELECT to read data from any table in the database. They inject a UNION query that selects from a different table — like pg_authid to get password hashes, or any table with sensitive data. They can also use semicolons to run entirely separate statements. DROP TABLE users semicolon — and your users table is gone. Or INSERT INTO users to create an admin account. Or COPY to read files from the server filesystem.

```sql
-- Payload 1: UNION attack — read password hashes
-- Input: ' UNION SELECT rolname, rolpassword FROM pg_authid --
postgres=# SELECT name, email FROM users WHERE id = '' UNION SELECT rolname, rolpassword FROM pg_authid --';
     name      |                email
---------------+--------------------------------------
 postgres      | SCRAM-SHA-256$4096:salt$stored...
 app_user      | SCRAM-SHA-256$4096:salt$stored...

-- Payload 2: Destructive — drop a table
-- Input: '; DROP TABLE users; --

-- Payload 3: Data exfiltration — read files
-- Input: '; COPY pg_authid TO '/tmp/hashes.txt'; --

-- ALL of these work when queries are built by string concatenation
```

### Parameterized Queries in Every Language
**Explanation:** Let us see parameterized queries in the most common programming languages. In Python with psycopg2, you use percent-s placeholders. In Python with psycopg3, you use percent-s or dollar-sign placeholders. In Java with JDBC, you use question marks. In Node.js with pg, you use dollar-sign-number placeholders. The key rule: NEVER concatenate user input into a SQL string. Always use your driver's parameterization mechanism.

```sql
-- Python (psycopg2/psycopg3):
-- cursor.execute(
--   "SELECT * FROM users WHERE username = %s AND password = %s",
--   (username, password)
-- )

-- Java (JDBC):
-- PreparedStatement ps = conn.prepareStatement(
--   "SELECT * FROM users WHERE username = ? AND password = ?");
-- ps.setString(1, username);
-- ps.setString(2, password);

-- Node.js (pg):
-- client.query(
--   'SELECT * FROM users WHERE username = $1 AND password = $2',
--   [username, password]
-- )

-- Go (pgx):
-- rows, err := conn.Query(ctx,
--   "SELECT * FROM users WHERE username = $1 AND password = $2",
--   username, password)
```

### PL/pgSQL — EXECUTE Injection Risk
**Explanation:** Inside PostgreSQL itself, PL/pgSQL functions have the same risk. The EXECUTE command runs dynamic SQL. If you build the SQL string by concatenating parameters, you have SQL injection inside your own database. The fix is the format function with the %L placeholder for literal values and %I for identifiers like table and column names. The format function properly quotes and escapes values. Alternatively, use EXECUTE with USING clause, which separates values from the SQL structure — just like parameterized queries in application code.

```sql
-- DANGEROUS: concatenation in EXECUTE
CREATE FUNCTION bad_search(search TEXT) RETURNS SETOF users AS $$
BEGIN
  RETURN QUERY EXECUTE
    'SELECT * FROM users WHERE name = ''' || search || '''';
  -- Attacker input: ' OR 1=1 --
  -- Becomes: SELECT * FROM users WHERE name = '' OR 1=1 --'
END; $$ LANGUAGE plpgsql;

-- SAFE: format() with %L for literals, %I for identifiers
CREATE FUNCTION safe_search(search TEXT) RETURNS SETOF users AS $$
BEGIN
  RETURN QUERY EXECUTE
    format('SELECT * FROM users WHERE name = %L', search);
END; $$ LANGUAGE plpgsql;

-- ALSO SAFE: EXECUTE ... USING
  RETURN QUERY EXECUTE 'SELECT * FROM users WHERE name = $1' USING search;
```

### SECURITY DEFINER + Injection = Privilege Escalation
**Explanation:** SECURITY DEFINER functions run with the privileges of the function owner, not the caller. This is like setuid programs in Linux. If a SECURITY DEFINER function has SQL injection, an attacker with minimal privileges can escalate to the function owner's privileges — often the superuser. This is the most dangerous form of SQL injection inside PostgreSQL. Always audit SECURITY DEFINER functions for injection, and always set a secure search_path to prevent schema attacks.

```sql
-- DANGEROUS: SECURITY DEFINER with dynamic SQL
CREATE FUNCTION admin_lookup(tbl TEXT) RETURNS SETOF RECORD AS $$
BEGIN
  RETURN QUERY EXECUTE 'SELECT * FROM ' || tbl;
  -- Runs as function OWNER (superuser!)
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attacker calls:
-- SELECT * FROM admin_lookup('pg_authid; DROP TABLE users; --');
-- Runs DROP TABLE as superuser!

-- SAFE: Use format(%I) for identifiers + set search_path
CREATE FUNCTION safe_lookup(tbl TEXT) RETURNS SETOF RECORD AS $$
BEGIN
  RETURN QUERY EXECUTE format('SELECT * FROM %I', tbl);
END; $$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;  -- prevent schema hijacking
```

### Defense in Depth — Least Privilege
**Explanation:** Parameterized queries are the primary defense, but defense-in-depth adds more layers. Principle of least privilege — the application database role should only have permissions it actually needs. If the app only reads and writes to specific tables, do not give it superuser or even CREATE permission. If an injection happens, the damage is limited to what that role can do. Input validation is another layer — validate data types, lengths, and formats before they reach the database. A username should be alphanumeric, an age should be a positive integer, an email should match a pattern.

```sql
-- Create a restricted application role
postgres=# CREATE ROLE web_app WITH LOGIN PASSWORD 'app_pass_2026';
CREATE ROLE

-- Grant ONLY what the app needs
postgres=# GRANT CONNECT ON DATABASE myapp TO web_app;
postgres=# GRANT USAGE ON SCHEMA public TO web_app;
postgres=# GRANT SELECT, INSERT, UPDATE ON users, orders, products TO web_app;
postgres=# GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO web_app;

-- NO superuser, NO CREATE, NO DROP, NO DELETE on critical tables
-- Even with SQL injection, attacker CANNOT:
--   DROP TABLE, CREATE ROLE, read pg_authid, COPY to files
```

### PostgreSQL PREPARE and EXECUTE
**Explanation:** PostgreSQL has a built-in prepared statement mechanism. PREPARE creates a named statement with dollar-sign placeholders. EXECUTE runs it with actual values. Prepared statements are parsed and planned once, then reused with different values. This is both a performance optimization and a security measure — the SQL structure is fixed and cannot be changed by input values.

```sql
-- Create a prepared statement
postgres=# PREPARE user_lookup (text) AS
postgres-#   SELECT id, name, email FROM users WHERE username = $1;
PREPARE

-- Execute with normal input
postgres=# EXECUTE user_lookup('alice');
 id |  name  |       email
----+--------+-------------------
  1 | Alice  | alice@example.com

-- Execute with malicious input — treated as data, not SQL
postgres=# EXECUTE user_lookup('admin'' OR 1=1 --');
 id | name | email
----+------+-------
(0 rows)
-- The injection attempt is treated as a literal string value
-- It searched for a user literally named: admin' OR 1=1 --
```

### Safe Dynamic Query Function
**Explanation:** Let us build a complete safe function in PL/pgSQL that handles dynamic queries correctly. This function allows searching a configurable table with configurable columns, using format with percent-I for identifiers and EXECUTE USING for values. It also validates inputs against a whitelist to prevent unauthorized table access.

```sql
CREATE OR REPLACE FUNCTION safe_dynamic_search(
    p_table TEXT,
    p_column TEXT,
    p_value TEXT
) RETURNS SETOF RECORD AS $$
DECLARE
    allowed_tables TEXT[] := ARRAY['users','products','orders'];
    allowed_columns TEXT[] := ARRAY['name','email','status'];
BEGIN
    -- Whitelist validation
    IF NOT (p_table = ANY(allowed_tables)) THEN
        RAISE EXCEPTION 'Table not allowed: %', p_table;
    END IF;
    IF NOT (p_column = ANY(allowed_columns)) THEN
        RAISE EXCEPTION 'Column not allowed: %', p_column;
    END IF;

    -- %I for identifiers, $1 USING for values
    RETURN QUERY EXECUTE
        format('SELECT * FROM %I WHERE %I = $1', p_table, p_column)
        USING p_value;
END;
$$ LANGUAGE plpgsql SECURITY INVOKER
SET search_path = public;
```

### Built-in Quoting Functions
**Explanation:** PostgreSQL also provides built-in escaping functions. quote_literal takes a string and wraps it in single quotes with proper escaping — including handling NULL values. quote_ident wraps an identifier in double quotes only when needed — like when a table name has spaces or is a reserved word. And quote_nullable works like quote_literal but returns the string NULL for null inputs instead of raising an error. These functions are useful in older code and in DO blocks where format is not available, but format with percent-L and percent-I is the modern preferred approach because it combines the quoting and the string building in one step, which is harder to get wrong.

```sql
-- quote_literal(): safely quote a VALUE
postgres=# SELECT quote_literal('O''Brien');
 quote_literal
--------------
 'O''Brien'

-- quote_ident(): safely quote an IDENTIFIER
postgres=# SELECT quote_ident('user name');
 quote_ident
-------------
 "user name"

-- quote_nullable(): like quote_literal but NULL-safe
postgres=# SELECT quote_nullable(NULL);
 quote_nullable
----------------
 NULL

-- Modern equivalent with format():
postgres=# SELECT format('WHERE name = %L AND tbl = %I', 'O''Brien', 'user name');
                      format
---------------------------------------------------
 WHERE name = 'O''Brien' AND tbl = "user name"
```

### Beginner Traps — Injection Mistakes
**Explanation:** Beginner trap number one — escaping instead of parameterizing. Some developers try to escape single quotes by doubling them. This is fragile and has been bypassed many times throughout history with Unicode tricks, multi-byte character exploits, and encoding attacks. Always use parameterized queries — not escaping. Trap two: thinking stored procedures are safe by default. If a stored procedure uses EXECUTE with concatenation, it is just as vulnerable. Trap three: forgetting about LIKE patterns. The percent and underscore characters are wildcards in LIKE. User input in a LIKE clause should escape these characters to prevent unintended pattern matching.

```sql
-- Trap 1: Escaping instead of parameterizing
-- BAD: replace(input, '''', '''''')
-- Bypassed by: Unicode tricks, encoding attacks, multi-byte chars
-- Fix: ALWAYS use parameterized queries

-- Trap 2: Stored procedures with EXECUTE + concatenation
-- Stored procedures are NOT automatically safe!
-- Use format(%L, %I) or EXECUTE...USING

-- Trap 3: LIKE pattern injection
-- User input: %admin%
-- SELECT * FROM users WHERE name LIKE '%' || input || '%'
-- Becomes: LIKE '%%admin%%' — matches differently than expected
-- Fix: Escape % and _ in user input before LIKE:
postgres=# SELECT * FROM users
postgres-# WHERE name LIKE '%' || replace(replace($1, '%', '\%'), '_', '\_') || '%';
```


---

## 5. Common Beginner Traps & How to Fix Them

### ORM Safety — Common Traps
ORMs like SQLAlchemy, Django ORM, and Hibernate automatically parameterize queries. But they still have injection risks. The biggest trap is raw SQL methods. Every ORM provides a way to write raw SQL — and developers use it for complex queries. If you concatenate user input in raw SQL, you are back to square one. Another trap is the order_by or filter clauses that accept column names from user input. Column names cannot be parameterized — they are identifiers, not values. You must whitelist allowed column names.

### Beginner Traps — Injection Mistakes
Beginner trap number one — escaping instead of parameterizing. Some developers try to escape single quotes by doubling them. This is fragile and has been bypassed many times throughout history with Unicode tricks, multi-byte character exploits, and encoding attacks. Always use parameterized queries — not escaping. Trap two: thinking stored procedures are safe by default. If a stored procedure uses EXECUTE with concatenation, it is just as vulnerable. Trap three: forgetting about LIKE patterns. The percent and underscore characters are wildcards in LIKE. User input in a LIKE clause should escape these characters to prevent unintended pattern matching.

```sql
-- Trap 1: Escaping instead of parameterizing
-- BAD: replace(input, '''', '''''')
-- Bypassed by: Unicode tricks, encoding attacks, multi-byte chars
-- Fix: ALWAYS use parameterized queries

-- Trap 2: Stored procedures with EXECUTE + concatenation
-- Stored procedures are NOT automatically safe!
-- Use format(%L, %I) or EXECUTE...USING

-- Trap 3: LIKE pattern injection
-- User input: %admin%
-- SELECT * FROM users WHERE name LIKE '%' || input || '%'
-- Becomes: LIKE '%%admin%%' — matches differently than expected
-- Fix: Escape % and _ in user input before LIKE:
SELECT * FROM users
WHERE name LIKE '%' || replace(replace($1, '%', '\%'), '_', '\_') || '%';
```


---

## 6. Hands-On Practice Exercises (Try It Yourself!)

1. Open your terminal and connect to your local practice database: `psql -U postgres -d practice`
2. Open and execute the companion `materials.sql` script: `\i materials.sql`
3. Verify the execution outputs and experiment with the parameters and queries covered in this class.


---

## 7. Key Takeaways & Cheat Sheet

Here is your SQL injection prevention checklist. Follow these rules and injection becomes impossible in your application.

- **ALWAYS use parameterized queries — never concatenate user input**
- **PL/pgSQL: format(%L) for values, format(%I) for identifiers**
- **PL/pgSQL: EXECUTE ... USING for dynamic values**
- **Whitelist allowed table/column names for dynamic queries**
- **App roles: least privilege — no DROP, no superuser, no COPY**
- **SECURITY DEFINER: audit + SET search_path = public**
- **ORM raw SQL: parameterize it just like direct SQL**
- **LIKE clauses: escape % and _ in user input**

Let us summarize. SQL injection happens when user input becomes SQL syntax through string concatenation. The fix is parameterized queries — always, everywhere, no exceptions. In PL/pgSQL, use format with percent-L for values and percent-I for identifiers, or EXECUTE with USING. Apply least privilege to application roles so even successful injection causes minimal damage. Audit SECURITY DEFINER functions carefully. And never rely on escaping — use parameterization.

- **Injection = user input becomes SQL syntax (via concatenation)**
- **Fix: parameterized queries ($1, %s, ?) — ALWAYS, NO exceptions**
- **PL/pgSQL: format(%L values, %I identifiers) or EXECUTE...USING**
- **Least privilege: app roles can only do what they need**
- **SECURITY DEFINER + injection = privilege escalation**
- **ORM raw SQL is still vulnerable — parameterize it**
- **Never rely on escaping — it has been bypassed many times**
- **Defense in depth: params + least privilege + input validation**


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
